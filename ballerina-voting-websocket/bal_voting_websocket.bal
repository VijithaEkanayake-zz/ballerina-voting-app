import ballerina/http;
import ballerina/log;
import ballerina/io;

map<http:WebSocketListener> connections;
map<string> votes;
json voteResults;

service<http:Service> hello bind { port: 9090 } {

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
        voteResults = countVotes(votes);
        broadcast(voteResults);
    }
}

service<http:WebSocketService> VoteApp {

    // This resource will trigger when a new text message arrives to the chat server
    onText(endpoint caller, string text) {
        votes[caller.id] = text;
        voteResults = countVotes(votes);
        broadcast(voteResults);

    }

    // This resource will trigger when a existing connection closes
    onClose(endpoint caller, int statusCode, string reason) {
        // Broadcast the message to existing connections
        var removeVote = votes.remove(caller.id);
        var closeCon = connections.remove(caller.id);
        voteResults = countVotes(votes);
        broadcast(voteResults);
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

// Calculates the total agaist each choice
function countVotes(map votesMap) returns json {
    int countA = 0;
    int countB = 0;
    int countC = 0;
    int countD = 0;

    foreach vote in votesMap {
        if (vote == "A") {
            countA++;
        } else if (vote == "B") {
            countB++;
        } else if (vote == "C") {
            countC++;
        } else if (vote == "D") {
            countD++;
        }
    }
    return { "A": countA, "B": countB, "C": countC, "D": countD, "connConout" : lengthof connections.keys() };
}
