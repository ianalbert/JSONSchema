JSONSchema
==========

A JSON Schema validator in Obj-C.

**As of 2014-02-16, this library is still in early development.**

JSON Schema is a way of specifying the expected structure of a JSON document by way of a rule set. A JSON Schema validator can apply these rules against a JSON document to ensure it complies or report errors for any violations it finds.

One use would be in client unit tests to fetch responses from a server and ensure they conform to the format the client expects. This can help systematically identify problems, subtle or otherwise, that might cause problems in the app.

Another use is to use the validator in production on every response coming back from the server. This approach serves as a safety mechanism, ensuring that an errant or unexpected response does not cause a client crash. For example, if the client expects a certain JSON property to be a string but the server returns a number, array, or object, an unvalidated response could cause a crash when string methods are attempted on the value. By validating the response and rejecting invalid responses the client can gracefully skip the response and show an error screen to the user. It could additionally "phone home" details of the schema validation so that server developers can quickly address the problem.

JSON Schemas you write for server responses should live in the client codebase. It is generally not a good idea to have the server send down these schemas at runtime. You can think of the schema as a contract for what the client code expects and can process. It is descriptive, not prescriptive. Changing the schema does not change the Obj-C code of your client. Therefore the schemas should be baked in the same as any client source code file. They should be checked into the client code repository and branched, versioned, and tagged along with the other code.

Conversely, to validate a client JSON request the server can opt to use a JSON Schema validator to ensure the request matches what its code can handle. However, server software generally doesn't run Obj-C, so this library isn't useful for that task. See http://json-schema.org/implementations.html for a list of JSON Schema validators for other programming languages.
