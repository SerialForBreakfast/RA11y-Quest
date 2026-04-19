# Resolves a single simulator UDID from `xcrun simctl list devices available --json`.
#
# Input: JSON file (pass as jq's input file argument).
# jq --arg:
#   family     "iPhone" or "iPad"
#   preferred  exact device name to try first, or ""
#   persisted  last-working UDID to reuse if still listed, or ""
#
# Output: raw UDID (use jq -r).

def available_devices($data; $fam):
  [ $data.devices | to_entries[] | .value[]
    | select(.isAvailable and (.name | contains($fam)))
  ];

def iphone_prefs:
  ["iPhone 17", "iPhone 16 Pro", "iPhone 16", "iPhone 15 Pro", "iPhone 15", "iPhone 14 Pro", "iPhone 14"];

def ipad_prefs:
  ["iPad Pro (13-inch)", "iPad Pro (12.9-inch)", "iPad Pro", "iPad Air", "iPad"];

def prefs_for($fam):
  if $fam == "iPhone" then iphone_prefs else ipad_prefs end;

def try_prefs($avail; $prefs):
  if ($prefs | length) == 0 then
    empty
  else
    ($avail
      | map(select(.name | startswith($prefs[0])))
      | if length > 0 then sort_by(.name) | reverse | .[0] else empty end)
    // try_prefs($avail; $prefs[1:])
  end;

. as $data
| available_devices($data; $family) as $avail
| if ($avail | length) == 0 then
    ([$data.devices | to_entries[] | .value[] | select(.isAvailable) | .name] | unique | join(", ")) as $names
    | error("No available " + $family + " simulator. All available simulators: " + $names)
  else
    (if ($persisted != "") then ($avail | map(select(.udid == $persisted)) | .[0] // empty) else empty end)
    // (if ($preferred != "") then ($avail | map(select(.name == $preferred)) | .[0] // empty) else empty end)
    // try_prefs($avail; prefs_for($family))
    // ($avail | sort_by(.name) | reverse | .[0])
    | .udid
  end
