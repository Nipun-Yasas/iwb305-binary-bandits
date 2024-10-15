import ballerina/http;
import ballerina/jwt;
import ballerina/sql;
import ballerinax/mysql;

configurable string jwtSecret = "mysecretkey";
configurable string jwtIssuer = "ballerina-app";
configurable string jwtAudience = "frontend-client";

type UserAuh record {|

    string email;
    string password;

|};

// MySQL Client Configuration
mysql:Client dbClient = check new ("localhost", "root", "KaviskaDilshan12#$", "ballerina-001", 3306);

// Define JWT issuer
// jwt:IssuerConfig jwtIssuerConfig = {
//     username: "ballerina",
//     issuer: "wso2",
//     audience: "vEwzbcasJVQm1jVYHUHCjhxZ4tYa",
//     expTime: 3600,
//     signatureConfig: {
//         config: {
//             keyFile: "/path/to/private.key"
//         }
//     }
// };

// Create a listener
//listener http:Listener loginListener = new (8080);

service /auth on httpListener {

    // Login endpoint that accepts email and password
    resource function post login(http:Request req, http:Caller caller, @http:Payload UserAuh userAuth) returns error? {
        string email = userAuth.email;
        string password = userAuth.password;

        // Validate email and password against the database
        if authenticateUser(email, password) {
            // If authenticated, generate a JWT token
            string userId = check getUserId(email); // Fetch user ID based on email
            // string jwtToken = check jwt:issue(jwtIssuerConfig);
            jwt:IssuerConfig issuerConfig = {
                issuer: "your-app",
                audience: "your-users",
                expTime: 3600, // Token expiration time in seconds
                customClaims: {
                    "username": email
                }
            };
            string jwtToken = check jwt:issue(issuerConfig);
            json response = {message: "Login successful", userId: userId, token: jwtToken};
            check caller->respond(response);
        } else {
            map<string> errorResponse = {"error": "Invalid email or password"};
            check caller->respond(errorResponse);
        }
    }

    // A simple protected resource
    // resource function get protectedResource(http:Caller caller, http:Request req) returns error? {
    //     // Extract the session token from the cookie
    //     http:Cookie[] cookies = req.getCookies();
    //     http:Cookie? sessionCookie = cookies.filter(c => c.name == "session-token").getOrElse(() => ());

    //     if sessionCookie is http:Cookie {
    //         string token = sessionCookie.value;
    //         jwt:Verifier jwtVerifier = check new ({
    //             issuer: jwtIssuer,
    //             audience: jwtAudience,
    //             signatureConfig: {
    //                 key: jwtSecret,
    //                 algorithm: jwt:HS256
    //             }
    //         });
    //         // Validate the JWT token
    //         jwt:Payload|jwt:Error payload = jwtVerifier.verify(token);
    //         if payload is jwt:Payload {
    //             string userId = payload.sub;
    //             json response = {message: "Protected data", userId: userId};
    //             check caller->respond(response);
    //         } else {
    //             json errorResponse = {error: "Invalid session token"};
    //             check caller->respond(errorResponse);
    //         }
    //     } else {
    //         json errorResponse = {error: "No session token found"};
    //         check caller->respond(errorResponse);
    //     }
    // }

    resource function post register(http:Request req,http:Caller caller, @http:Payload UserAuh userAuth) returns error? {
        // Hash the user's password before storing it
        string email = userAuth.email;
        string password = userAuth.password;


        // Prepare an SQL query to insert the ner into the database
        sql:ParameterizedQuery query = `INSERT INTO users (email, password) VALUES (${email}, ${password})`;

        // Execute the query
        sql:ExecutionResult result = check dbClient->execute(query);
        if result.affectedRowCount == 0 {
            return error("User registration failed");
        }

       if authenticateUser(email, password) {
            // If authenticated, generate a JWT token
            string userId = check getUserId(email); // Fetch user ID based on email
            // string jwtToken = check jwt:issue(jwtIssuerConfig);
            jwt:IssuerConfig issuerConfig = {
                issuer: "your-app",
                audience: "your-users",
                expTime: 3600, // Token expiration time in seconds
                customClaims: {
                    "username": email
                }
            };
            string jwtToken = check jwt:issue(issuerConfig);
            json response = {message: "Login successful", userId: userId, token: jwtToken};
            check caller->respond(response);
        }
    }
}

// Mock function to validate email and password against the database
function authenticateUser(string email, string password) returns boolean {
    //return true;
    sql:ParameterizedQuery query = `SELECT password FROM user WHERE email = ${email}`;
    stream<record {|string password;|}, sql:Error?> resultStream = dbClient->query(query);
    var result = resultStream.next();
    if result is record {|record {|string password;|} value;|} {
        record {|string password;|} userRecord = result.value;
        return userRecord.password == password;
    }
    return false;
}

// Mock function to retrieve user ID based on email
function getUserId(string email) returns string|error {
    sql:ParameterizedQuery query = `SELECT id FROM user WHERE email = ${email}`;
    stream<record {|int id;|}, sql:Error?> resultStream = dbClient->query(query);
    var result = resultStream.next();
    if result is record {|record {|int id;|} value;|} {
        record {|int id;|} userRecord = result.value;
        return userRecord.id.toString();
    }
    return error("User not found");
}

// function hashPassword(string password) returns string {
//     byte[] hashedBytes = crypto:hashSha256(password.toBytes());
//     return hashedBytes.toBase16();
// }
