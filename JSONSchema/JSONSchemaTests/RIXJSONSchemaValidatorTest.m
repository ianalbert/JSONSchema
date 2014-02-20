//
//  RIXJSONSchemaValidatorTest.m
//  JSONSchema
//
//  Created by Ian Albert on 2014-02-16.
//  Copyright (c) 2014 Ian Albert. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "RIXJSONSchemaValidator.h"

#define RIXAssertErrorExists(errorCode, path) {\
    BOOL found = NO;\
    for (NSUInteger i = 0; i < errors.count; i++) {\
        NSError *error = errors[i];\
        if (error.code == errorCode && [error.userInfo[RIXJSONSchemaValidatorErrorJSONPointerKey] isEqual:path]) {\
            [errors removeObjectAtIndex:i];\
            found = YES;\
            break;\
        }\
    }\
    if (!found) {\
        XCTFail(@"Error not found. %i %@", errorCode, path);\
    }\
}

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

// Simple schema
- (void)test00
{
    NSDictionary *schemaDict = [self loadJSONWithName:@"test-schema-00"];
    id doc = [self loadJSONWithName:@"test-doc-00"];
    RIXJSONSchemaValidator *validator = [[RIXJSONSchemaValidator alloc] initWithSchema:schemaDict];
    NSArray *errors = [validator validateJSONValue:doc];
    XCTAssertTrue(errors.count == 0, @"Found unexpected errors %@", errors);
}

// Validation success
- (void)test01
{
    NSDictionary *schemaDict = [self loadJSONWithName:@"test-schema-01"];
    id doc = [self loadJSONWithName:@"test-doc-01"];
    RIXJSONSchemaValidator *validator = [[RIXJSONSchemaValidator alloc] initWithSchema:schemaDict];
    NSArray *errors = [validator validateJSONValue:doc];
    XCTAssertTrue(errors.count == 0, @"Found unexpected errors %@", errors);
}

// Validation failures
- (void)test02
{
    NSDictionary *schemaDict = [self loadJSONWithName:@"test-schema-01"];
    id doc = [self loadJSONWithName:@"test-doc-02"];
    RIXJSONSchemaValidator *validator = [[RIXJSONSchemaValidator alloc] initWithSchema:schemaDict];
    NSMutableArray *errors = [[validator validateJSONValue:doc] mutableCopy];

    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorObjectMissingRequiredProperty, @"");

    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectType, @"/i00");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorNumberNotAMultiple, @"/i01");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorNumberBelowMinimum, @"/i02");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorNumberAboveMaximum, @"/i03");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorNumberBelowMinimum, @"/i04");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectType, @"/i05");

    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectType, @"/n00");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorNumberNotAMultiple, @"/n01");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorNumberBelowMinimum, @"/n02");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorNumberAboveMaximum, @"/n03");

    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectType, @"/b00");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectType, @"/b01");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectType, @"/b02");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectType, @"/b03");

    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectType, @"/s00");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorStringShorterThanMinimumLength, @"/s01");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorStringDoesNotMatchPattern, @"/s01");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorStringLongerThanMaximumLength, @"/s02");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorStringDoesNotMatchPattern, @"/s02");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorStringDoesNotMatchPattern, @"/s03");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorStringDoesNotMatchPattern, @"/s04");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorStringDoesNotMatchPattern, @"/s05");

    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorArrayTooFewElements, @"/a00");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorArrayTooManyElements, @"/a01");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorArrayElementsNotUnique, @"/a01");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectType, @"/a02/0");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectType, @"/a02/1");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectType, @"/a02/2");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorArrayElementsNotUnique, @"/a03");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectType, @"/a03/1");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectType, @"/a03/2");

    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorObjectTooFewProperties, @"/o00");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorObjectTooManyProperties, @"/o01");

    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueNotInEnum, @"/es00");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueNotInEnum, @"/es01");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectType, @"/es01");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueNotInEnum, @"/ei00");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueNotInEnum, @"/ei01");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectType, @"/ei01");

    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueFailedAnyOf, @"/any00");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueFailedAnyOf, @"/any01");

    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueFailedAllOf, @"/all00");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueFailedAllOf, @"/all01");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueFailedAllOf, @"/all02");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueFailedAllOf, @"/all03");

    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueFailedOneOf, @"/one00");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueFailedOneOf, @"/one01");

    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueFailedNot, @"/not00");

    // We should have accounted for every error already.
    XCTAssertEqualObjects(@[], errors, @"");
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
