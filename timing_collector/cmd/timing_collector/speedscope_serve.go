package main

import "encoding/json"

func speedscopeJSONForView(data []byte, profileIdx int) []byte {
	var file speedscopeFile
	if err := json.Unmarshal(data, &file); err != nil {
		return data
	}
	if len(file.Profiles) == 0 {
		return data
	}
	sanitized, err := sanitizeSpeedscopeProfiles(file.Profiles)
	if err == nil && len(sanitized) > 0 {
		file.Profiles = sanitized
	}
	if profileIdx < 0 || profileIdx >= len(file.Profiles) {
		profileIdx = 0
	}
	file.ActiveProfileIndex = profileIdx
	b, err := json.Marshal(file)
	if err != nil {
		return data
	}
	return b
}
