import ballerina/http;

service / on new http:Listener(8081) {
    resource function get .(http:Caller caller, http:Request req) returns error? {
      //get rote
    }
}