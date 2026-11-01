-- Original audit detections now run as positive regression assertions in CI.
assert(loadfile("tests/retail-transient-ownership.lua"))()
