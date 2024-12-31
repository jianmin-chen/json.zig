Typed JSON parser. See example in `src/json_test.zig`. 

* Typed options somewhat limited currently (e.g., enums/unions aren't supported yet).
* Better error handling.
* Better public facing types - for example, returned `json.Typed` structs contain a (valid) dangling pointer to a stream.
* Needs to pass all testing in `tests`.
* Formatting options for `json.stringify`. 
* Is having a wrapper around `std.StringHashMap` really the best option, or is there a way to parse directly a `std.StringHashMap`, which would make things a lot nicer?
* Benchmark to speed up.