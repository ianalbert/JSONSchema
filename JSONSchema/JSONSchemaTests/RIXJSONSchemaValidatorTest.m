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

@interface RIXJSONSchemaValidatorTestCustomFormat : NSObject <RIXJSONSchemaFormatValidator>
@end
@implementation RIXJSONSchemaValidatorTestCustomFormat

- (BOOL)isValidValue:(id)value forFormatName:(NSString *)formatName
{
    return ([value isEqual:@"legal"]);
}

@end

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

- (BOOL)validateSchema:(NSDictionary *)schema
{
    NSDictionary *JSONSchema = [self loadJSONWithName:@"json-schema-draft-04"];
    RIXJSONSchemaValidator *schemaValidator = [[RIXJSONSchemaValidator alloc] initWithSchema:JSONSchema];
    NSArray *errors = [schemaValidator validateJSONValue:schema];
    if (errors) {
        NSLog(@"Invalid schema:\n%@", errors);
    }
    return (errors.count == 0);
}

- (void)testSimpleSchema
{
    NSDictionary *schemaDict = [self loadJSONWithName:@"test-schema-00"];
    if (![self validateSchema:schemaDict]) {
        XCTFail(@"Invalid schema");
        return;
    }
    id doc = [self loadJSONWithName:@"test-doc-00"];
    RIXJSONSchemaValidator *validator = [[RIXJSONSchemaValidator alloc] initWithSchema:schemaDict];
    NSArray *errors = [validator validateJSONValue:doc];
    XCTAssertTrue(errors.count == 0, @"Found unexpected errors %@", errors);
}

- (void)testAllValidationRules
{
    NSDictionary *schemaDict = [self loadJSONWithName:@"test-schema-01"];
    if (![self validateSchema:schemaDict]) {
        XCTFail(@"Invalid schema");
        return;
    }
    id doc = [self loadJSONWithName:@"test-doc-02"];
    RIXJSONSchemaValidator *validator = [[RIXJSONSchemaValidator alloc] initWithSchema:schemaDict];
    [validator setFormatValidator:[[RIXJSONSchemaValidatorTestCustomFormat alloc] init] forFormatName:@"custom"];
    NSMutableArray *errors = [[validator validateJSONValue:doc] mutableCopy];

    // Account for every error we received. By convention, the test document
    // numbers positive case keys with 1xx suffixes and negative cases with 2xx.

    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorObjectMissingRequiredProperty, @"");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorObjectInvalidProperty, @"");

    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectType, @"/integer-200");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorNumberNotAMultiple, @"/integer-201");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorNumberBelowMinimum, @"/integer-202");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorNumberAboveMaximum, @"/integer-203");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorNumberBelowMinimum, @"/integer-204");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectType, @"/integer-205");

    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectType, @"/number-200");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorNumberNotAMultiple, @"/number-201");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorNumberBelowMinimum, @"/number-202");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorNumberAboveMaximum, @"/number-203");

    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectType, @"/boolean-200");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectType, @"/boolean-201");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectType, @"/boolean-202");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectType, @"/boolean-203");

    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectType, @"/string-200");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorStringShorterThanMinimumLength, @"/string-201");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorStringDoesNotMatchPattern, @"/string-201");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorStringLongerThanMaximumLength, @"/string-202");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorStringDoesNotMatchPattern, @"/string-202");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorStringDoesNotMatchPattern, @"/string-203");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorStringDoesNotMatchPattern, @"/string-204");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorStringDoesNotMatchPattern, @"/string-205");

    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorArrayTooFewElements, @"/array-200");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorArrayTooManyElements, @"/array-201");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorArrayElementsNotUnique, @"/array-201");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectType, @"/array-202/0");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectType, @"/array-202/1");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectType, @"/array-202/2");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorArrayElementsNotUnique, @"/array-203");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectType, @"/array-203/1");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectType, @"/array-203/2");

    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorObjectTooFewProperties, @"/object-200");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorObjectTooManyProperties, @"/object-201");

    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueNotInEnum, @"/enum-string-200");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueNotInEnum, @"/enum-string-201");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectType, @"/enum-string-201");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueNotInEnum, @"/enum-integer-200");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueNotInEnum, @"/enum-integer-201");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectType, @"/enum-integer-201");

    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueFailedAnyOf, @"/anyOf-200");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueFailedAnyOf, @"/anyOf-201");

    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueFailedAllOf, @"/allOf-200");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueFailedAllOf, @"/allOf-201");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueFailedAllOf, @"/allOf-202");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueFailedAllOf, @"/allOf-203");

    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueFailedOneOf, @"/oneOf-200");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueFailedOneOf, @"/oneOf-201");

    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueFailedNot, @"/not-200");

    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorObjectFailedDependency, @"/array-dependencies-200");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorObjectFailedDependency, @"/array-dependencies-201");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorObjectFailedDependency, @"/array-dependencies-202");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorObjectFailedDependency, @"/array-dependencies-202"); // two missing properties

    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorObjectFailedDependency, @"/schema-dependencies-200");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorObjectFailedDependency, @"/schema-dependencies-201");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorObjectFailedDependency, @"/schema-dependencies-202");

    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectFormat, @"/format-date-time-200");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectFormat, @"/format-date-time-201");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectFormat, @"/format-date-time-202");

    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectFormat, @"/format-email-200");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectFormat, @"/format-email-201");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectFormat, @"/format-email-202");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectFormat, @"/format-email-203");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectFormat, @"/format-email-204");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectFormat, @"/format-email-205");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectFormat, @"/format-email-206");

    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectFormat, @"/format-hostname-200");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectFormat, @"/format-hostname-201");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectFormat, @"/format-hostname-202");

    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectFormat, @"/format-ipv4-200");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectFormat, @"/format-ipv4-201");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectFormat, @"/format-ipv4-202");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectFormat, @"/format-ipv4-203");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectFormat, @"/format-ipv4-204");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectFormat, @"/format-ipv4-205");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectFormat, @"/format-ipv4-206");

    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectFormat, @"/format-ipv6-200");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectFormat, @"/format-ipv6-201");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectFormat, @"/format-ipv6-202");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectFormat, @"/format-ipv6-203");

    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectFormat, @"/format-uri-200");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectFormat, @"/format-uri-201");

    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectFormat, @"/format-custom-200");

    // We should have accounted for every error already.
    XCTAssertEqualObjects(@[], errors, @"");
}

- (void)testExternalReferences
{
    // Schema references another schema in the bundle
    NSDictionary *schemaDict = [self loadJSONWithName:@"test-schema-03"];
    if (![self validateSchema:schemaDict]) {
        XCTFail(@"Invalid schema");
        return;
    }
    id doc = [self loadJSONWithName:@"test-doc-03"];
    RIXJSONSchemaValidator *validator = [[RIXJSONSchemaValidator alloc] initWithSchema:schemaDict];
    [validator setFormatValidator:[[RIXJSONSchemaValidatorTestCustomFormat alloc] init] forFormatName:@"custom"];
    // Unit tests don't have a main bundle, so set one explicitly
    RIXJSONSchemaBundleURIResolver *URIResolver = [[RIXJSONSchemaBundleURIResolver alloc] initWithBundle:[self mainBundle]];
    [validator addURIResolver:URIResolver];
    NSMutableArray *errors = [[validator validateJSONValue:doc] mutableCopy];

    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorStringDoesNotMatchPattern, @"/illegalValue00");
    RIXAssertErrorExists(RIXJSONSchemaValidatorErrorValueIncorrectType, @"/illegalValue01");

    XCTAssertEqualObjects(@[], errors, @"");
}

- (NSBundle *)mainBundle
{
    return [NSBundle bundleWithIdentifier:@"com.rixafrix.JSONSchemaTests"];
}

- (id)loadJSONWithName:(NSString *)name
{
    NSBundle *bundle = [self mainBundle];
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
