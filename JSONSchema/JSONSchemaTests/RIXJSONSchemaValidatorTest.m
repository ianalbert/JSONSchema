//
//  RIXJSONSchemaValidatorTest.m
//  JSONSchema
//
//  Created by Ian Albert on 2014-02-16.
//  Copyright (c) 2014 Ian Albert. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "RIXJSONSchemaValidator.h"

@interface RIXJSONSchemaValidatorTest : XCTestCase

@end

@implementation RIXJSONSchemaValidatorTest

- (void)setUp
{
    [super setUp];
    // Put setup code here; it will be run once, before the first test case.
}

- (void)tearDown
{
    // Put teardown code here; it will be run once, after the last test case.
    [super tearDown];
}

- (void)test00
{
    NSDictionary *schemaDict = [self loadJSONWithName:@"test-schema-00"];
    id doc = [self loadJSONWithName:@"test-doc-00"];
    RIXJSONSchemaValidator *validator = [[RIXJSONSchemaValidator alloc] initWithSchema:schemaDict];
    NSArray *errors = [validator validateJSONValue:doc];
    XCTAssertTrue(errors.count == 0, @"Found unexpected errors %@", errors);
}

- (void)test01
{
    NSDictionary *schemaDict = [self loadJSONWithName:@"test-schema-01"];
    id doc = [self loadJSONWithName:@"test-doc-01"];
    RIXJSONSchemaValidator *validator = [[RIXJSONSchemaValidator alloc] initWithSchema:schemaDict];
    NSArray *errors = [validator validateJSONValue:doc];
    XCTAssertTrue(errors.count == 0, @"Found unexpected errors %@", errors);
}

- (id)loadJSONWithName:(NSString *)name
{
    NSBundle *bundle = [NSBundle bundleWithIdentifier:@"com.rixafrix.JSONSchemaTests"];
    XCTAssertNotNil(bundle, @"Could not create bundle");
    NSString *path = [bundle pathForResource:name ofType:@"json"];
    XCTAssertNotNil(path, @"Could not resolve path for %@.json", name);
    NSData *data = [NSData dataWithContentsOfFile:path];
    XCTAssertNotNil(data, @"Could not load data for %@.json", name);
    NSError *JSONError = nil;
    id value = [NSJSONSerialization JSONObjectWithData:data options:0 error:&JSONError];
    XCTAssertNotNil(value, @"Could not load %@.json", name);
    XCTAssertNil(JSONError, @"Encountered JSON parsing error %@", JSONError);
    return value;
}

@end
