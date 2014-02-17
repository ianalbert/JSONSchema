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
    XCTAssertNotNil(schemaDict, @"Could not load schema");
    id doc = [self loadJSONWithName:@"test-doc-00"];
    XCTAssertNotNil(doc, @"Could not load document");
    RIXJSONSchemaValidator *validator = [[RIXJSONSchemaValidator alloc] initWithSchema:schemaDict];
    NSArray *errors = [validator validateJSONValue:doc];
    XCTAssertTrue(errors.count == 0, @"Found unexpected errors");
}

- (id)loadJSONWithName:(NSString *)name
{
    NSBundle *bundle = [NSBundle bundleWithIdentifier:@"com.rixafrix.JSONSchemaTests"];
    NSString *path = [bundle pathForResource:name ofType:@"json"];
    NSData *data = [NSData dataWithContentsOfFile:path];
    id value = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    return value;
}

@end
