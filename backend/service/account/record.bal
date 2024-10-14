import ballerina/http;
import ballerina/sql;
import ballerinax/mysql;

type Record record {|
    string? number;
    string? branch;
    string? types;
    int? id;
|};

type DeleteRecord record {|
    int id;
|};