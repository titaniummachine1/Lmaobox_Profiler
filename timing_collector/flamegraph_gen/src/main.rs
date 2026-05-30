//! Reads Brendan Gregg folded format (stack;names <nanoseconds>) and writes SVG.
//! Invoked by timing_collector.exe — not meant to be run by users directly.

use anyhow::{Context, Result};
use clap::Parser;
use inferno::flamegraph::{from_reader, Direction, Options};
use std::fs::File;
use std::io::{BufReader, BufWriter};
use std::path::PathBuf;

#[derive(Parser)]
#[command(name = "flamegraph_gen", about = "Folded stacks -> SVG (inferno)")]
struct Args {
    /// Input file: lines of "frame;child;leaf <count>"
    #[arg(short, long)]
    input: PathBuf,

    /// Output SVG path
    #[arg(short, long)]
    output: PathBuf,

    /// Graph title (shown above flame graph)
    #[arg(short, long, default_value = "flame graph")]
    title: String,
}

fn main() -> Result<()> {
    let args = Args::parse();

    let mut options = Options::default();
    options.title = args.title;
    options.image_width = Some(1400);
    options.frame_height = 20;
    options.min_width = 0.0;
    options.hash = true;
    // Root at top, children grow downward (icicle-style — not classic bottom-up flame)
    options.direction = Direction::Straight;

    let input = BufReader::new(
        File::open(&args.input)
            .with_context(|| format!("open {}", args.input.display()))?,
    );
    let output = BufWriter::new(
        File::create(&args.output)
            .with_context(|| format!("create {}", args.output.display()))?,
    );

    from_reader(&mut options, input, output).context("inferno flamegraph")?;
    Ok(())
}
