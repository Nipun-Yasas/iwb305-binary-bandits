// import ballerina/io;
// import ballerinax/mysql;
// import ballerina/sql;

// public function main() returns error? {
//     mysql:Client|sql:Error dbClientResult = new ("localhost", "root", "KaviskaDilshan12#$", "dad_travel", 3306);

//     if (dbClientResult is sql:Error) {
//         io:println({"error": dbClientResult.message()});
//         return dbClientResult;
//     }

//     mysql:Client dbClient = <mysql:Client>dbClientResult;

//     sql:ParameterizedQuery query = `SELECT * FROM students 
//                                 WHERE id < 10 AND age > 12`;

//     // Execute the query
//     stream<record {int id; string name; int age;}, sql:Error?> accountStream = dbClient->query(query);

//     json[] account = [];

//     // Iterate through the result set and append to the account array.
//     error? e = accountStream.forEach(function(record {int id; string name; int age;} student) {
//         account.push({
//             "id": student.id,
//             "name": student.name,
//             "age": student.age
//         });
//     });

//     if (e is error) {
//         io:println({"error": e.message()});
//         return e;
//     }

//     error? dberror = dbClient.close();
//     if (dberror is error) {
//         io:println({"error": dberror.message()});
//         return dberror;
//     }

//     // Close the stream to avoid resource leaks
//     //accountStream.close();

//     io:println(account);
//     return;
// }

import ballerina/http;

type Album readonly & record {|
    string title;
    string artist;
|};

table<Album> key(title) albums = table [
    {title: "Blue Train", artist: "John Coltrane"},
    {title: "Jeru", artist: "Gerry Mulligan"}
];

service / on new http:Listener(9090) {

    resource function get albums() returns Album[] {
        return albums.toArray();
    }

    resource function post albums(Album album) returns Album {
        albums.add(album);
        return album;
    }
}
