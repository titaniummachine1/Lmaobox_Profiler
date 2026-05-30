package main

import "fmt"

// enforceMonotonicEventTimes bumps event "at" so times never decrease (speedscope requires this).
// Stack order is unchanged; only timestamps are nudged forward by 1ns when needed.
func enforceMonotonicEventTimes(events []speedscopeEvent) []speedscopeEvent {
	if len(events) == 0 {
		return events
	}
	out := make([]speedscopeEvent, len(events))
	cursor := events[0].At
	out[0] = events[0]
	for i := 1; i < len(events); i++ {
		at := events[i].At
		if at <= cursor {
			at = cursor + 1
		}
		out[i] = speedscopeEvent{Type: events[i].Type, At: at, Frame: events[i].Frame}
		cursor = at
	}
	return out
}

func syncEventedProfileBounds(p *speedscopeEventedProfile) {
	if len(p.Events) == 0 {
		return
	}
	p.StartValue = p.Events[0].At
	p.EndValue = p.Events[len(p.Events)-1].At
}

func sanitizeEventedProfile(p speedscopeEventedProfile) (speedscopeEventedProfile, error) {
	if len(p.Events) < 2 {
		return p, fmt.Errorf("profile %q: need at least 2 events", p.Name)
	}
	p.Events = enforceMonotonicEventTimes(p.Events)
	if err := validateEventedStack(p.Events); err != nil {
		return p, fmt.Errorf("profile %q: %w", p.Name, err)
	}
	syncEventedProfileBounds(&p)
	if p.EndValue <= p.StartValue {
		return p, fmt.Errorf("profile %q: zero duration", p.Name)
	}
	return p, nil
}

func validateEventedStack(events []speedscopeEvent) error {
	var stack []int
	var lastAt int64
	for i, e := range events {
		if e.At < lastAt {
			return fmt.Errorf("event %d: at %d < previous %d", i, e.At, lastAt)
		}
		lastAt = e.At
		switch e.Type {
		case "O":
			stack = append(stack, e.Frame)
		case "C":
			if len(stack) == 0 {
				return fmt.Errorf("event %d: close with empty stack", i)
			}
			top := stack[len(stack)-1]
			stack = stack[:len(stack)-1]
			if top != e.Frame {
				return fmt.Errorf("event %d: close frame %d != stack top %d", i, e.Frame, top)
			}
		default:
			return fmt.Errorf("event %d: unknown type %q", i, e.Type)
		}
	}
	if len(stack) != 0 {
		return fmt.Errorf("unclosed frames on stack: %v", stack)
	}
	return nil
}

func sanitizeSpeedscopeProfiles(profiles []speedscopeEventedProfile) ([]speedscopeEventedProfile, error) {
	out := make([]speedscopeEventedProfile, 0, len(profiles))
	var errs []string
	for _, p := range profiles {
		sanitized, err := sanitizeEventedProfile(p)
		if err != nil {
			errs = append(errs, err.Error())
			continue
		}
		out = append(out, sanitized)
	}
	if len(out) == 0 {
		if len(errs) > 0 {
			return nil, fmt.Errorf("%s", errs[0])
		}
		return nil, fmt.Errorf("no valid speedscope profiles")
	}
	return out, nil
}
