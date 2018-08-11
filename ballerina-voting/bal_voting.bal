// Copyright (c) 2018 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/http;
import ballerina/log;
import ballerina/io;

map<http:WebSocketListener> connections;
int countA = 0;
int countB = 0;
int countC = 0;
int countD = 0;
json votes;
@http:ServiceConfig {
    cors: {
        allowOrigins: ["*"],
        allowCredentials: false,
        allowHeaders: ["Content-Type"],
        exposeHeaders: ["*"],
        maxAge: 84900
    }
}
service<http:Service> hello bind { port: 9090 } {

    // Invoke all resources with arguments of server connector and request.
    @http:ResourceConfig {
        methods: ["GET", "POST", "OPTIONS"],
        path: "/sayHello",
        cors: {
            allowOrigins: ["*"],
            allowCredentials: false,
            allowHeaders: ["Content-Type"],
            maxAge: 84900
        }
    }
    sayHello(endpoint caller, http:Request req) {
        http:Response res = new;

        if (req.method == "OPTIONS") {
            res.setHeader("Access-Control-Allow-Origin", "*");
            res.setHeader("Access-Control-Allow-Methods", "*");
            res.setHeader("Access-Control-Allow-Headers", "*");
            caller->respond(res) but {
                error e => log:printError(
                               "Error sending response", err = e)
            };
            done;
        }
        json requestPayload = untaint check req.getJsonPayload();
        string voteValue = requestPayload.voteValue.toString();
        if (voteValue == "A") {
            countA++;
        } else if (voteValue == "B") {
            countB++;
        } else if (voteValue == "C") {
            countC++;
        } else if (voteValue == "D") {
            countD++;
        }

        votes = { "A": countA, "B": countB, "C": countC, "D": countD };
        res.setPayload(untaint votes);
        broadcast(votes);

        // Send the response back to the caller.
        caller->respond(res) but {
            error e => log:printError(
                           "Error sending response", err = e)
        };
    }

    // Resource to upgrade from HTTP to WebSocket
    @http:ResourceConfig {
        webSocketUpgrade: {
            upgradePath: "/vote",
            upgradeService: VoteApp
        }
    }
    upgrader(endpoint caller, http:Request req) {
        endpoint http:WebSocketListener wsCaller;
        map<string> headers;
        wsCaller = caller->acceptWebSocketUpgrade(headers);
        connections[wsCaller.id] = wsCaller;
        broadcast(votes);
    }
}

service<http:WebSocketService> VoteApp {

    // This resource will trigger when a new text message arrives to the voting server
    onText(endpoint caller, string text) {
        // Broadcast the message to existing connections
        broadcast(votes);
        // Print the message in the server console
        io:println(votes.toString());
    }

    // This resource will trigger when a existing connection closes
    onClose(endpoint caller, int statusCode, string reason) {
        // Broadcast the message to existing connections
        var closeCon = connections.remove(caller.id);
        broadcast(reason);
    }
}

// Send the text to all connections in the connections map
function broadcast(json text) {
    endpoint http:WebSocketListener caller;
    // Iterate through all available connections in the connections map
    foreach conn in connections {
        //io:println(text);
        caller = conn;
        // Push the text message to the connection
        caller->pushText(text) but {
            error e => log:printError("Error sending message")
        };
    }
}
