use std::collections::HashMap;
use std::sync::{Arc, Mutex, OnceLock};
use std::time::Instant;
use tiny_http::{Response, Server};

const MAX_TIMER_AGE_SECS: u64 = 30;

static SERVER_START: OnceLock<Instant> = OnceLock::new();

struct TimerEntry {
    start: Instant,
}

fn main() {
    let server = Server::http("127.0.0.1:9876").expect("Failed to start server on port 9876");
    SERVER_START.get_or_init(Instant::now);
    let timers: Arc<Mutex<HashMap<String, TimerEntry>>> = Arc::new(Mutex::new(HashMap::new()));

    println!("Timing server running on http://127.0.0.1:9876");
    println!("Endpoints:");
    println!("  /now            - Monotonic nanoseconds since server start");
    println!("  /start?name=XXX - Start named timer");
    println!("  /stop?name=XXX  - Stop named timer, returns nanoseconds");

    for request in server.incoming_requests() {
        let url = request.url();

        let response_text = if url.starts_with("/now") {
            let start = SERVER_START.get().unwrap();
            let nanos = start.elapsed().as_nanos();
            format!("{}", nanos)
        } else {
            let mut timers_lock = timers.lock().unwrap();
            cleanup_stale_timers(&mut timers_lock);

            let result = if url.starts_with("/start") {
                if let Some(name) = extract_name(url) {
                    let entry = TimerEntry {
                        start: Instant::now(),
                    };
                    timers_lock.insert(name.to_string(), entry);
                    "0".to_string()
                } else {
                    "-1".to_string()
                }
            } else if url.starts_with("/stop") {
                if let Some(name) = extract_name(url) {
                    if let Some(entry) = timers_lock.remove(name) {
                        let elapsed = entry.start.elapsed();
                        format!("{}", elapsed.as_nanos())
                    } else {
                        "-1".to_string()
                    }
                } else {
                    "-1".to_string()
                }
            } else {
                "unknown".to_string()
            };

            drop(timers_lock);
            result
        };

        let response = Response::from_string(response_text);
        let _ = request.respond(response);
    }
}

fn extract_name(url: &str) -> Option<&str> {
    url.split("name=").nth(1)
}

fn cleanup_stale_timers(timers: &mut HashMap<String, TimerEntry>) {
    let now = Instant::now();
    timers.retain(|_, entry| now.duration_since(entry.start).as_secs() < MAX_TIMER_AGE_SECS);
}
