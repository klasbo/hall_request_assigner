//debug = optimal_hall_requests;

import elevator_state;
import elevator_algorithm;

import std.algorithm;
import std.conv;
import std.datetime;
import std.range;
import std.stdio;


int doorOpenDuration    = 3000;
int travelDuration      = 2500;


bool[2][][string] optimalHallRequests(
    bool[2][]                       hallReqs,
    LocalElevatorState[string]      elevatorStates,
){    
    auto reqs   = hallReqs.toReq;
    auto states = initialStates(elevatorStates);
    
    debug(optimal_hall_requests) writefln("states:\n  %(%s,\n  %)", states);
    debug(optimal_hall_requests) writefln("reqs:\n%(  %(%s, %)\n%)", reqs);
    
    foreach(ref s; states){
        performInitialMove(s, reqs);
    }
    
    while(true){
        debug(optimal_hall_requests) writeln;
        debug(optimal_hall_requests) writefln("states:\n  %(%s,\n  %)", states);
        debug(optimal_hall_requests) writefln("reqs:\n%(  %(%s, %)\n%)", reqs);
    
        bool done = true;
        if(reqs.anyUnassigned){
            done = false;
        }
        if(unvisitedAreImmediatelyAssignable(reqs, states)){
            debug(optimal_hall_requests) writefln("unvisited immediately assignable");
            assignImmediate(reqs, states);
            done = true;
        }
        
        if(done){
            break;
        }
    
    
        states.sort!("a.time < b.time")();
        performSingleMove(states[0], reqs);
    }
    
    
    bool[2][][string] result;
    foreach(id, _; elevatorStates){
        result[id] = new bool[2][](hallReqs.length);
    }
    for(int f = 0; f < hallReqs.length; f++){
        for(int c = 0; c < 2; c++){
            if(reqs[f][c].active){
                result[reqs[f][c].assignedTo][f][c] = true;
            }
        }
    }
    
        
    debug(optimal_hall_requests) writefln("\nfinal:");
    debug(optimal_hall_requests) writefln("states:\n  %(%s,\n  %)", states);
    debug(optimal_hall_requests) writefln("reqs:\n%(  %(%s, %)\n%)", reqs);
    debug(optimal_hall_requests) writefln("result:\n%(  %s : %([%(%d, %)]%|, %)\n%)", result);
    
    return result;
}

private :

struct Req {
    bool    active;
    string  assignedTo;
}

struct State {
    string              id;
    LocalElevatorState  state;
    Duration            time;
}




bool[2][] filterReq(alias fn)(Req[2][] reqs){
    return reqs.map!(a => a.to!(Req[]).map!(fn).array).array.to!(bool[2][]);
}

Req[2][] toReq(bool[2][] hallReqs){
    return hallReqs.map!(a => a.to!(bool[]).map!(b => Req(b, string.init)).array).array.to!(Req[2][]);
}

ElevatorState withReqs(alias fn)(State s, Req[2][] reqs){
    return s.state.withRequests(reqs.filterReq!(fn));
}

bool anyUnassigned(Req[2][] reqs){
    return reqs
        .filterReq!(a => a.active && a.assignedTo == string.init)
        .map!(a => a.to!(bool[]).any).any;
}

State[] initialStates(LocalElevatorState[string] states){
    return zip(states.keys, states.values)
        .sort!(q{a[0] < b[0]})
        .zip(iota(states.length))
        .map!(a => 
            State(a[0][0], a[0][1], a[1].usecs)
        )
        .array;
}



void performInitialMove(ref State s, ref Req[2][] reqs){
    debug(optimal_hall_requests) writefln("initial move: %s", s);
    final switch(s.state.behaviour) with(ElevatorBehaviour){    
    case doorOpen:
        debug(optimal_hall_requests) writefln("  closing door");
        s.time += doorOpenDuration.msecs/2;
        goto case idle;
    case idle:
        foreach(c; 0..2){
            if(reqs[s.state.floor][c].active){
                debug(optimal_hall_requests) writefln("  taking req %s at current floor", c);
                reqs[s.state.floor][c].assignedTo = s.id;
                s.time += doorOpenDuration.msecs;
            }
        }
        break;
    case moving:
        debug(optimal_hall_requests) writefln("  arriving");
        s.state.floor += s.state.direction;
        s.time += travelDuration.msecs/2;
        break;
    }
}

void performSingleMove(ref State s, ref Req[2][] reqs){

    debug(optimal_hall_requests) writefln("single move: %s", s);
    
    auto e = s.withReqs!(a => a.active && (a.assignedTo == string.init || a.assignedTo == s.id))(reqs);
    
    debug(optimal_hall_requests) writefln("%s", e);
    
    final switch(s.state.behaviour) with(ElevatorBehaviour){
    case moving:
        if(e.shouldStop){
            debug(optimal_hall_requests) writefln("  stopping");
            s.state.behaviour = doorOpen;
            s.time += doorOpenDuration.msecs;
            e.clearReqsAtFloor((CallType c){
                final switch(c) with(CallType){
                case hallUp, hallDown:
                    reqs[s.state.floor][c].assignedTo = s.id;
                    break;
                case cab:
                    s.state.cabRequests[s.state.floor] = false;
                }
            });
        } else {
            debug(optimal_hall_requests) writefln("  continuing");
            s.state.floor += s.state.direction;
            s.time += travelDuration.msecs;
        }
        break;
    case idle, doorOpen:
        s.state.direction = e.chooseDirection;
        if(s.state.direction == Dirn.stop){
            s.state.behaviour = idle;
            debug(optimal_hall_requests) writefln("  idling");
        } else {
            s.state.behaviour = moving;
            debug(optimal_hall_requests) writefln("  departing");
            s.state.floor += s.state.direction;
            s.time += travelDuration.msecs;
        }
        break;
    }
}

// all unvisited hall requests are at floors with elevators with no cab requests
bool unvisitedAreImmediatelyAssignable(Req[2][] reqs, State[] states){
    foreach(f, reqsAtFloor; reqs){
        foreach(c, req; reqsAtFloor){
            if(req.active && req.assignedTo == string.init){
                if(states.filter!(a => a.state.floor == f && !a.state.cabRequests.any).empty){
                    return false;
                }
            }
        }
    }
    return true;
}

void assignImmediate(ref Req[2][] reqs, ref State[] states){
    foreach(f, ref reqsAtFloor; reqs){
        foreach(c, ref req; reqsAtFloor){
            if(req.active && req.assignedTo == string.init){
                foreach(ref s; states){
                    if(s.state.floor == f && !s.state.cabRequests.any){
                        req.assignedTo = s.id;
                        s.time += doorOpenDuration.msecs;
                    }
                }
            }
        }
    }    
}









unittest {
    LocalElevatorState[string] states = [
        "1" : LocalElevatorState(ElevatorBehaviour.idle,     0, Dirn.stop, [0, 0, 0, 0].to!(bool[])),
        "2" : LocalElevatorState(ElevatorBehaviour.doorOpen, 3, Dirn.down, [1, 0, 0, 0].to!(bool[])),
        "3" : LocalElevatorState(ElevatorBehaviour.moving,   2, Dirn.up,   [1, 0, 0, 1].to!(bool[])),
    ];

    bool[2][] hallreqs = [
        [false, false],
        [true,  false],
        [false, false],
        [false, false],
    ];
    

    auto optimal = optimalHallRequests(hallreqs, states);
    assert(optimal == [
        "1" : [[0,0],[1,0],[0,0],[0,0]].to!(bool[2][]),
        "2" : [[0,0],[0,0],[0,0],[0,0]].to!(bool[2][]),
        "3" : [[0,0],[0,0],[0,0],[0,0]].to!(bool[2][]),
    ]);
}

unittest {
    // Two elevators moving from each "end" toward the middle floors
    // Elevators should stop at the closest order, even if it is in the "wrong" direction
    LocalElevatorState[string] states = [
        "1" : LocalElevatorState(ElevatorBehaviour.idle, 0, Dirn.stop, [0, 0, 0, 0].to!(bool[])),
        "2" : LocalElevatorState(ElevatorBehaviour.idle, 3, Dirn.stop, [0, 0, 0, 0].to!(bool[])),
    ];

    bool[2][] hallreqs = [
        [false, false],
        [false, true],
        [true,  false],
        [false, false],
    ];
    

    auto optimal = optimalHallRequests(hallreqs, states);
    assert(optimal == [
        "1" : [[0,0],[0,1],[0,0],[0,0]].to!(bool[2][]),
        "2" : [[0,0],[0,0],[1,0],[0,0]].to!(bool[2][]),
    ]);

    states = [
        "1" : LocalElevatorState(ElevatorBehaviour.moving, 0, Dirn.up,   [0, 0, 0, 0].to!(bool[])), // only change from prev scenario
        "2" : LocalElevatorState(ElevatorBehaviour.idle,   3, Dirn.stop, [0, 0, 0, 0].to!(bool[])),
    ];

    optimal = optimalHallRequests(hallreqs, states);
    assert(optimal == [
        "1" : [[0,0],[0,1],[0,0],[0,0]].to!(bool[2][]),
        "2" : [[0,0],[0,0],[1,0],[0,0]].to!(bool[2][]),
    ]);
}

unittest {
    // Two elevators are the same number of floors away from an order, but one is moving toward it
    // Should give the order to the moving elevator
    LocalElevatorState[string] states = [
        "27" : LocalElevatorState(ElevatorBehaviour.moving,   1,  Dirn.down, [0, 0, 0, 0].to!(bool[])),
        "20" : LocalElevatorState(ElevatorBehaviour.doorOpen, 1,  Dirn.down, [0, 0, 0, 0].to!(bool[])),
    ];

    bool[2][] hallreqs = [
        [true,  false],
        [false, false],
        [false, false],
        [false, false],
    ];
    
    auto optimal = optimalHallRequests(hallreqs, states);
    assert(optimal == [
        "27" : [[1,0],[0,0],[0,0],[0,0]].to!(bool[2][]),
        "20" : [[0,0],[0,0],[0,0],[0,0]].to!(bool[2][]),
    ]);
}



