//
//  RIXArchitectureTest.m
//  JSONSchema
//
//  Created by Ian Albert on 2014-01-23.
//  Copyright (c) 2014 Ian Albert. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface RIXArchitectureTest : XCTestCase

@end

/**
 * Tests assumptions about the architecture and core class behaviors that the
 * JSON Schema validator depends on.
 */
@implementation RIXArchitectureTest

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

/**
 * Tests assumptions we use to determine the original JSON data type that an
 * NSNumber describes.
 */
- (void)testNSNumberReflection
{
    NSString *testJSON = @"{"
        "\"bool-false\": false,"
        "\"bool-true\": true,"
        "\"integer-zero\": 0,"
        "\"integer-one\": 1,"
        "\"integer-two\": 2,"
        "\"number-zero\": 0.0,"
        "\"number-one\": 1.0,"
        "\"number-decimal\": 1.5,"
        "\"largeinteger\": 9000000000"
    "}";
    NSData *JSONData = [testJSON dataUsingEncoding:NSUTF8StringEncoding];
    NSError *JSONError = nil;
    NSDictionary *object = [NSJSONSerialization JSONObjectWithData:JSONData options:0 error:&JSONError];
    XCTAssertNil(JSONError, @"Test JSON did not parse");

    NSNumber *num;

    num = object[@"bool-false"];
    XCTAssertTrue(strcmp([num objCType], @encode(BOOL)) == 0 || strcmp([num objCType], @encode(char)) == 0, @"JavaScript false is stored as %s, not %s or %s", [num objCType], @encode(BOOL), @encode(char));
    num = object[@"bool-true"];
    XCTAssertTrue(strcmp([num objCType], @encode(BOOL)) == 0 || strcmp([num objCType], @encode(char)) == 0, @"JavaScript true is stored as %s, not %s or %s", [num objCType], @encode(BOOL), @encode(char));
    num = object[@"integer-zero"];
    XCTAssertTrue(strcmp([num objCType], @encode(NSInteger)) == 0, @"JavaScript integer 0 is stored as %s, not %s", [num objCType], @encode(NSInteger));
    num = object[@"integer-one"];
    XCTAssertTrue(strcmp([num objCType], @encode(NSInteger)) == 0, @"JavaScript integer 1 is stored as %s, not %s", [num objCType], @encode(NSInteger));
    num = object[@"integer-two"];
    XCTAssertTrue(strcmp([num objCType], @encode(NSInteger)) == 0, @"JavaScript integer 2 is stored as %s, not %s", [num objCType], @encode(NSInteger));
    num = object[@"number-zero"];
    XCTAssertTrue(strcmp([num objCType], @encode(double)) == 0, @"JavaScript number 0.0 is stored as %s, not %s", [num objCType], @encode(double));
    num = object[@"number-one"];
    XCTAssertTrue(strcmp([num objCType], @encode(double)) == 0, @"JavaScript number 1.0 is stored as %s, not %s", [num objCType], @encode(double));
    num = object[@"number-decimal"];
    XCTAssertTrue(strcmp([num objCType], @encode(double)) == 0, @"JavaScript number 1.5 is stored as %s, not %s", [num objCType], @encode(double));
    num = object[@"largeinteger"];
    XCTAssertTrue(strcmp([num objCType], @encode(int64_t)) == 0, @"JavaScript large integer is stored as %s, not %s", [num objCType], @encode(int64_t));
}

@end
