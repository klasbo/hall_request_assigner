Hall request assigner
=====================

Made for "on-the-fly" / "dynamic" hall request assignment, ie. where all hall requests are completely re-assigned every time a new request (or other event) arrives.

### JSON format:

Input:
```
{
    "hallRequests" : 
        [[Boolean, Boolean], ...],
    "states" : 
        {
            "id_1" : {
                "behaviour"     : < "idle" | "moving" | "doorOpen" >
                "floor"         : NonNegativeInteger
                "direction"     : < "up" | "down" | "stop" >
                "cabRequests"   : [Boolean, ...]
            },
            "id_2" : {...}
        }
}
```

Output:
```
{
    "id_1" : [[Boolean, Boolean], ...],
    "id_2" : ...
}
```




### Example JSON:

Input:
```
{
    "hallRequests" : 
        [[false,false],[true,false],[false,false],[false,true]],
    "states" : {
        "one" : {
            "behaviour":"moving",
            "floor":2,
            "direction":"up",
            "cabRequests":[false,false,true,true]
        },
        "two" : {
            "behaviour":"idle",
            "floor":0,
            "direction":"stop",
            "cabRequests":[false,false,false,false]
        }
    }
}
```

Output:
```
{
    "one" : [[false,false],[false,false],[false,false],[false,true]],
    "two" : [[false,false],[true,false],[false,false],[false,false]]
}
```


Usage
-----

### Downloading:

`git clone --recursive https://github.com/klasbo/hall_request_assigner`

### Building:

Run `build.sh`, or copy its one line of content and run that.

### Command line arguments:

 - `-i` | `--input` : JSON input. 
   - Example: `./hall_request_assigner --input '{"hallRequests":....}'`
 - `--travelDuration` : Travel time between two floors in milliseconds (default 2500)
 - `--doorOpenDuration` : Door open time in milliseconds (default 3000)
 
If JSON input is not passed on the command line, the program will read the first line from stdin instead. JSON output is written to stdout.
