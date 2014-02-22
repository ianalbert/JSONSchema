JSONSchema
==========

A [http://json-schema.org](JSON Schema) validator in Obj-C. This implementation is based off Internet Draft 4 of the specification.

# Introduction

JSON Schema is a way of specifying the expected structure of a JSON document by way of a rule set. A JSON Schema validator can apply these rules against a JSON document to ensure it complies or report errors for any violations it finds. While similar in function to an XML schema, JSON Schema is more legible, less verbose, and permissive-by-default.

# Installation

This library is designed to be extremely lightweight. All you need to do to use it in your project is copy RIXJSONSchemaValidator.h and RIXJSONSchemaValidator.m into your project. It only requires the Foundation framework. The code uses ARC. If your project uses MRC then you will need to add the "-fobjc-arc" flag to RIXJSONSchemaValidator.m in the Build Phases tab of your project.

# Role

A schema is a contract that a document adheres to a specified format. As such, its most useful role is one of "keeping the other guy honest," which means using it against incoming data. For an iOS app or Mac application this means verifying what you're getting from a server is in the agreed-upon format.

Schemas should live with the code they protect. If a schema is intended to guard client code against responses coming from a server then they should live with that client code. When the schema changes the client code should change, and vice versa.

# Uses

One potential use is to incorporate schema validation in a unit test. The test can check responses from the server and ensure they conform to what the client expects. Schemas are checked into the project along with the rest of the client source code. It can be tricky to set up unit tests that fetch network responses asynchronously though.

Another use is to put the schema validator in the app or application code and use it to verify every response before handing it up to higher level logic. If a response does not validate then it is thrown out as invalid and treated as a server error. Because responses are always validated, code downstream can do less boilerplate defensive coding, such as type checking and bounds checking.

A modification to that strategy is to only use validation in development builds. This way problems can still be found during development but there will be no performance hit in the production app.

# Coding Goals

This project was written to be as lightweight as possible. It's contained in a single .h and single .m file for easy installation. It does not pull in lots of extra frameworks, and it requires no third-party libraries. Coding is as by-the-book as possible -- potentially at the cost of performance -- to reduce the chance of future evolutions of Obj-C breaking something in this code. There should be few if any "clever" hacks in place.
