//
//  RIXJSONSchemaValidator.m
//  JSONSchema
//
//  Created by Ian Albert on 2014-01-23.
//  Copyright (c) 2014 Ian Albert. All rights reserved.
//

#import "RIXJSONSchemaValidator.h"

#import <arpa/inet.h>

NSString *const RIXJSONSchemaValidatorErrorDomain = @"RIXJSONSchemaValidatorError";
NSString *const RIXJSONSchemaValidatorErrorJSONPointerKey = @"JSONPointer";
NSString *const RIXJSONSchemaValidatorErrorSuberrorsKey = @"suberrors";

typedef NS_ENUM(NSUInteger, RIXJSONDataType) {
    RIXJSONDataTypeUnknown = 0,

    RIXJSONDataTypeNull = (1 << 0),
    RIXJSONDataTypeBoolean = (1 << 1),
    RIXJSONDataTypeInteger = (1 << 2),
    RIXJSONDataTypeNumber = (1 << 3),
    RIXJSONDataTypeString = (1 << 4),
    RIXJSONDataTypeArray = (1 << 5),
    RIXJSONDataTypeObject = (1 << 6),

    RIXJSONDataTypeMaskAll = RIXJSONDataTypeNull | RIXJSONDataTypeBoolean | RIXJSONDataTypeInteger | RIXJSONDataTypeNumber | RIXJSONDataTypeString | RIXJSONDataTypeArray | RIXJSONDataTypeObject,
};

#define keyMainID @"id"
#define keyMainSchema @"$schema"
#define keyMainDefinitions @"definitions"
#define keyMainRef @"$ref"

#define keyNumberMultipleOf @"multipleOf"
#define keyNumberMinimum @"minimum"
#define keyNumberMaximum @"maximum"
#define keyNumberExclusiveMinimum @"exclusiveMinimum"
#define keyNumberExclusiveMaximum @"exclusiveMaximum"

#define keyStringMinLength @"minLength"
#define keyStringMaxLength @"maxLength"
#define keyStringPattern @"pattern"

#define keyArrayItems @"items"
#define keyArrayAdditionalItems @"additionalItems"
#define keyArrayMinItems @"minItems"
#define keyArrayMaxItems @"maxItems"
#define keyArrayUniqueItems @"uniqueItems"

#define keyObjectProperties @"properties"
#define keyObjectPatternProperties @"patternProperties"
#define keyObjectAdditionalProperties @"additionalProperties"
#define keyObjectDependencies @"dependencies"
#define keyObjectRequired @"required"
#define keyObjectMinProperties @"minProperties"
#define keyObjectMaxProperties @"maxProperties"

#define keyAnyEnum @"enum"
#define keyAnyType @"type"
#define keyAnyAllOf @"allOf"
#define keyAnyAnyOf @"anyOf"
#define keyAnyOneOf @"oneOf"
#define keyAnyNot @"not"
#define keyAnyFormat @"format"

#define keyMetaTitle @"title"
#define keyMetaDescription @"description"
#define keyMetaDefault @"default"

#define valueDatatypeArray @"array"
#define valueDatatypeBoolean @"boolean"
#define valueDatatypeInteger @"integer"
#define valueDatatypeNumber @"number"
#define valueDatatypeNull @"null"
#define valueDatatypeObject @"object"
#define valueDatatypeString @"string"

#define valueFormatDateTime @"date-time"
#define valueFormatEmail @"email"
#define valueFormatHostname @"hostname"
#define valueFormatIPV4 @"ipv4"
#define valueFormatIPV6 @"ipv6"
#define valueFormatURI @"uri"

RIXJSONDataType RIXJSONDataTypeFromString(NSString *string) {
    if ([string isEqualToString:valueDatatypeArray]) {
        return RIXJSONDataTypeArray;
    }
    if ([string isEqualToString:valueDatatypeBoolean]) {
        return RIXJSONDataTypeBoolean;
    }
    if ([string isEqualToString:valueDatatypeInteger]) {
        return RIXJSONDataTypeInteger;
    }
    if ([string isEqualToString:valueDatatypeNull]) {
        return RIXJSONDataTypeNull;
    }
    if ([string isEqualToString:valueDatatypeNumber]) {
        return RIXJSONDataTypeNumber;
    }
    if ([string isEqualToString:valueDatatypeObject]) {
        return RIXJSONDataTypeObject;
    }
    if ([string isEqualToString:valueDatatypeString]) {
        return RIXJSONDataTypeString;
    }
    return RIXJSONDataTypeUnknown;
}

RIXJSONDataType RIXJSONDataTypeFromStrings(NSArray *strings) {
    RIXJSONDataType dataTypeMask = 0;
    for (NSString *string in strings) {
        dataTypeMask |= RIXJSONDataTypeFromString(string);
    }
    return dataTypeMask;
}

NSArray* NSStringsFromRIXJSONDataType(RIXJSONDataType dataType) {
    NSMutableArray *names = [[NSMutableArray alloc] initWithCapacity:7];
    if (dataType & RIXJSONDataTypeArray) {
        [names addObject:valueDatatypeArray];
    }
    if (dataType & RIXJSONDataTypeBoolean) {
        [names addObject:valueDatatypeBoolean];
    }
    if (dataType & RIXJSONDataTypeInteger) {
        [names addObject:valueDatatypeInteger];
    }
    if (dataType & RIXJSONDataTypeNull) {
        [names addObject:valueDatatypeNull];
    }
    if (dataType & RIXJSONDataTypeNumber) {
        [names addObject:valueDatatypeNumber];
    }
    if (dataType & RIXJSONDataTypeObject) {
        [names addObject:valueDatatypeObject];
    }
    if (dataType & RIXJSONDataTypeString) {
        [names addObject:valueDatatypeString];
    }
    return names;
}

@class RIXJSONSchemaValidatorSchema;

@interface RIXJSONSchemaValidator ()

@property (nonatomic, strong) RIXJSONSchemaValidatorSchema *rootSchema;
@property (nonatomic, strong) NSMutableDictionary *patternToRegex; // NSString -> NSRegularExpression
@property (nonatomic, strong) NSMutableDictionary *URIToSchema; // NSURL -> RIXJSONSchemaValidatorSchema
@property (nonatomic, strong) NSMutableArray *URIResolvers; // id<RIXJSONSchemaValidatorURIResolver>[]
@property (nonatomic, strong) NSDictionary *defaultFormatValidators; // NSString format name -> id<RIXJSONSchemaFormatValidator>
@property (nonatomic, strong) NSMutableDictionary *customFormatValidators; // NSString format name -> id<RIXJSONSchemaFormatValidator>

- (RIXJSONSchemaValidatorSchema *)schemaForURI:(NSURL *)URI;

@end

@implementation NSNull (RIXJSONSchemaValidator)
- (RIXJSONDataType)JSONDataType
{
    return RIXJSONDataTypeNull;
}
@end

@implementation NSNumber (RIXJSONSchemaValidator)
- (RIXJSONDataType)JSONDataType
{
    static char const *boolTypes = "BcC";
    static char const *intTypes = "ilqcsILQCS";
    const char *selfType = [self objCType];
    if ((strstr(boolTypes, selfType) != NULL) && ([self integerValue] == 0 || [self integerValue] == 1)) {
        return RIXJSONDataTypeBoolean;
    }
    if (strstr(intTypes, selfType) != NULL) {
        return RIXJSONDataTypeInteger | RIXJSONDataTypeNumber;
    }
    return RIXJSONDataTypeNumber;
}
@end

@implementation NSString (RIXJSONSchemaValidator)
- (BOOL)containsNonNegativeInteger
{
    NSUInteger len = self.length;
    if (len == 0) {
        return NO;
    }
    for (NSUInteger i = 0; i < len; i++) {
        unichar ch = [self characterAtIndex:i];
        if (ch < '0' || ch > '9') {
            return NO;
        }
    }
    return YES;
}
- (NSUInteger)unsignedIntegerValueOrDefault:(NSUInteger)fallback
{
    NSUInteger len = self.length;
    if (len == 0) {
        return fallback;
    }
    NSUInteger value = 0;
    for (NSUInteger i = 0; i < len; i++) {
        unichar ch = [self characterAtIndex:i];
        if (ch < '0' || ch > '9') {
            return fallback;
        }
        NSUInteger d = (ch - '0');
        value = (value * 10) + d;
    }
    return value;
}
- (RIXJSONDataType)JSONDataType
{
    return RIXJSONDataTypeString;
}
- (NSString *)stringByAddingJSONPointerEscapes
{
    NSString *result = [self stringByReplacingOccurrencesOfString:@"~" withString:@"~0"];
    result = [result stringByReplacingOccurrencesOfString:@"/" withString:@"~1"];
    return result;
}
@end

@implementation NSDictionary (RIXJSONSchemaValidator)
- (RIXJSONDataType)JSONDataType
{
    return RIXJSONDataTypeObject;
}
- (id)objectAtJSONPointerSegment:(NSString *)segment
{
    return [self objectForKey:segment];
}
@end

@implementation NSArray (RIXJSONSchemaValidator)
- (RIXJSONDataType)JSONDataType
{
    return RIXJSONDataTypeArray;
}
- (id)objectAtJSONPointerSegment:(NSString *)segment
{
    NSUInteger index = [segment unsignedIntegerValueOrDefault:-1];
    if (index >= self.count) {
        return nil;
    }
    return [self objectAtIndex:index];
}
@end

@implementation NSObject (RIXJSONSchemaValidator)
- (id)objectAtJSONPointerSegment:(NSString *)segment
{
    return nil;
}
- (id)objectAtJSONPointer:(NSString *)JSONPointer
{
    NSUInteger len = [JSONPointer length];
    if (len == 0) {
        // Empty string = root node
        return self;
    }
    if ([JSONPointer characterAtIndex:0] != '/') {
        // Invalid pointer. Must be absolute and begin with a /, unless the empty string
        return nil;
    }
    id node = self;
    NSUInteger segmentStart = 1; // skip initial slash
    BOOL segmentNeedsEscape = NO;
    for (NSUInteger i = segmentStart; i < len; i++) {
        unichar ch = [JSONPointer characterAtIndex:i];
        if (ch == '/') {
            NSString *segment = [JSONPointer substringWithRange:NSMakeRange(segmentStart, i - segmentStart)];
            if (segmentNeedsEscape) {
                segment = [segment stringByReplacingOccurrencesOfString:@"~1" withString:@"/"];
                segment = [segment stringByReplacingOccurrencesOfString:@"~0" withString:@"~"];
            }
            node = [node objectAtJSONPointerSegment:segment];
            if (!node) {
                return nil;
            }
            segmentStart = i + 1;
            segmentNeedsEscape = NO;
        }
        else {
            if (ch == '~') {
                if (i + 1 >= len) {
                    // Truncated escape sequence
                    return nil;
                }
                unichar next = [JSONPointer characterAtIndex:i + 1];
                if (next != '0' && next != '1') {
                    // Illegal escape sequence
                    return nil;
                }
                segmentNeedsEscape = YES;
            }
        }
    }
    NSString *segment = [JSONPointer substringWithRange:NSMakeRange(segmentStart, len - segmentStart)];
    if (segmentNeedsEscape) {
        segment = [segment stringByReplacingOccurrencesOfString:@"~1" withString:@"/"];
        segment = [segment stringByReplacingOccurrencesOfString:@"~0" withString:@"~"];
    }
    node = [node objectAtJSONPointerSegment:segment];
    return node;
}
- (RIXJSONDataType)JSONDataType
{
    return RIXJSONDataTypeUnknown;
}
@end

@implementation NSURL (RIXJSONSchemaValidator)
- (NSString *)absoluteStringWithoutFragment
{
    NSString *str = self.absoluteString;
    NSRange hash = [str rangeOfString:@"#"];
    if (hash.location == NSNotFound) {
        return str;
    }
    return [str substringToIndex:hash.location];
}
+ (NSURL *)defaultRootJSONSchemaURI
{
    NSURL *URL = [[NSURL alloc] initWithString:@"#"];
    return URL;
}
- (NSURL *)normalizedRootJSONSchemaURI
{
    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:self resolvingAgainstBaseURL:YES];
    if ([components.fragment isEqualToString:@""]) {
        return self;
    }
    components.fragment = @"";
    return components.URL;
}
- (NSString *)JSONPointer
{
    NSString *fragment = [self.fragment stringByRemovingPercentEncoding];
    if (fragment.length == 0) {
        return @"";
    }
    if (![fragment hasPrefix:@"/"]) {
        NSString *ret = [@"/" stringByAppendingString:fragment];
        return ret;
    }
    return fragment;
}
- (NSURL *)URIRelativeToJSONReference:(NSString *)ref
{
    NSString *preNoFragment = [self absoluteStringWithoutFragment];
    NSURL *newURL = [[NSURL alloc] initWithString:ref relativeToURL:self];
    NSString *postNoFragment = [newURL absoluteStringWithoutFragment];
    if (![postNoFragment isEqual:preNoFragment]) {
        // URL changed. Fragment is replaced.
        return newURL;
    }
    // Same base URL. Resolve fragment.
    NSURLComponents *oldComponents = [[NSURLComponents alloc] initWithURL:self resolvingAgainstBaseURL:YES];
    NSURLComponents *newComponents = [[NSURLComponents alloc] initWithURL:newURL resolvingAgainstBaseURL:YES];
    if (oldComponents.fragment.length > 0) {
        if (newComponents.fragment) {
            if (![newComponents.fragment hasPrefix:@"/"]) {
                // New fragment is relative. Resolve against old fragment
                // "/", "foo/bar" -> "//foo/bar"
                // "blah", "bloo"
                if (![oldComponents.fragment hasPrefix:@"/"]) {
                    // E.g. old = #foo, new = #bar -> #/foo/bar
                    newComponents.fragment = [NSString stringWithFormat:@"/%@/%@", oldComponents.fragment, newComponents.fragment];
                }
                else {
                    // E.g. old = #/foo, new = #bar -> #/foo/bar
                    newComponents.fragment = [NSString stringWithFormat:@"%@/%@", oldComponents.fragment, newComponents.fragment];
                }
            }
            // else new ref was absolute, so leave it replacing the old fragment
        }
        else {
            // New ref didn't include a fragment, so default to root
            newComponents.fragment = @"";
        }
    }
    else if (!newComponents.fragment) {
        // No fragment. Default to root.
        newComponents.fragment = @"";
    }
    if (newComponents.fragment.length > 0 && ![newComponents.fragment hasPrefix:@"/"]) {
        newComponents.fragment = [@"/" stringByAppendingString:newComponents.fragment];
    }
    NSURL *URL = newComponents.URL;
    return URL;
}
@end

@interface RIXJSONSchemaValidatorSchema : NSObject
@property (nonatomic, weak) RIXJSONSchemaValidator *validator;
@property (nonatomic, strong) NSURL *URI;
@property (nonatomic, strong) NSDictionary *schema;
@property (nonatomic, strong) RIXJSONSchemaValidatorSchema *nextSchema;
@end



@implementation RIXJSONSchemaValidatorSchema
- (instancetype)initWithSchema:(NSDictionary *)schema
                           URI:(NSURL *)URI
                     validator:(RIXJSONSchemaValidator *)validator
{
    self = [super init];
    if (self) {
        _schema = schema;
        _URI = URI;
        _validator = validator;
    }
    return self;
}
- (id)objectForKeyedSubscript:(id)key
{
    id val = _schema[key];
    if (val) {
        // Value was in this schema
        return val;
    }
    if (_nextSchema) {
        // Value was in the next schema (or somewhere down the chain)
        return _nextSchema[key];
    }
    id ref = _schema[keyMainRef];
    if (ref) {
        NSURL *nextURI = [_URI URIRelativeToJSONReference:ref];
        _nextSchema = [_validator schemaForURI:nextURI];
        return _nextSchema[key];
    }
    return nil;
}
- (RIXJSONSchemaValidatorSchema *)schemaAtJSONPointer:(NSString *)JSONPointer
{
    id elem = [_schema objectAtJSONPointer:JSONPointer];
    if ([elem JSONDataType] != RIXJSONDataTypeObject) {
        return nil;
    }
    if (elem == _schema) {
        return self;
    }
    NSURL *subURI = [_URI URIRelativeToJSONReference:[@"#" stringByAppendingString:JSONPointer]];
    RIXJSONSchemaValidatorSchema *subschema = [[RIXJSONSchemaValidatorSchema alloc] initWithSchema:elem URI:subURI validator:_validator];
    return subschema;
}
@end

@interface RIXJSONSchemaValidatorContext : NSObject
@property (nonatomic, weak) RIXJSONSchemaValidator *validator;
@property (nonatomic, strong) NSMutableArray *errors; // NSArray[] of NSError[]
@property (nonatomic, strong) NSMutableArray *schemaStack; // RIXJSONSchemaValidatorSchema[]
@property (nonatomic, strong) NSMutableArray *currentJSONPath; // NSString or NSNumber
@end
@implementation RIXJSONSchemaValidatorContext

- (instancetype)initWithInitialSchema:(RIXJSONSchemaValidatorSchema *)schema
                            validator:(RIXJSONSchemaValidator *)validator
{
    self = [super init];
    if (self) {
        _schemaStack = [[NSMutableArray alloc] initWithObjects:schema, nil];
        _validator = validator;
        _currentJSONPath = [[NSMutableArray alloc] init];
        _errors = [[NSMutableArray alloc] init];
        NSMutableArray *topErrors = [[NSMutableArray alloc] init];
        [_errors addObject:topErrors];
    }
    return self;
}

- (void)addErrorCode:(NSInteger)errorCode
             message:(NSString *)pattern, ...
{
    va_list args;
    va_start(args, pattern);
    [self addErrorCode:errorCode suberrors:nil message:pattern args:args];
    va_end(args);
}

- (void)addErrorCode:(NSInteger)errorCode
           suberrors:(NSArray *)suberrors
             message:(NSString *)pattern, ...
{
    va_list args;
    va_start(args, pattern);
    [self addErrorCode:errorCode suberrors:suberrors message:pattern args:args];
    va_end(args);
}

- (void)addErrorCode:(NSInteger)errorCode
           suberrors:(NSArray *)suberrors
             message:(NSString *)pattern
                args:(va_list)args
{
    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
    if (pattern) {
        NSString *message = [[NSString alloc] initWithFormat:pattern arguments:args];
        userInfo[NSLocalizedDescriptionKey] = message;
    }
    NSString *path;
    if (_currentJSONPath.count == 0) {
        path = @"";
    }
    else {
        path = @"";
        for (id elem in _currentJSONPath) {
            path = [NSString stringWithFormat:@"%@/%@", path, [[[elem description] stringByAddingJSONPointerEscapes] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
        }
    }
    userInfo[RIXJSONSchemaValidatorErrorJSONPointerKey] = path;
    if (suberrors) {
        userInfo[RIXJSONSchemaValidatorErrorSuberrorsKey] = suberrors;
    }
    NSError *error = [NSError errorWithDomain:RIXJSONSchemaValidatorErrorDomain code:errorCode userInfo:userInfo];
    NSMutableArray *errors = [_errors lastObject];
    [errors addObject:error];
    [errors objectAtIndexedSubscript:0];
}

- (NSArray *)currentErrors
{
    return [_errors lastObject];
}

- (id)objectForKeyedSubscript:(id)key
{
    NSDictionary *schema = [self.schemaStack lastObject];
    return schema[key];
}

- (BOOL)boolForKey:(id)key orDefault:(BOOL)undefinedValue
{
    id elem = self[key];
    return ([elem isKindOfClass:[NSNumber class]]) ? [elem boolValue] : undefinedValue;
}

- (NSUInteger)allowedDataTypes
{
    id elem = self[keyAnyType];
    if (!elem) {
        return RIXJSONDataTypeMaskAll;
    }
    if ([elem JSONDataType] == RIXJSONDataTypeString) {
        return RIXJSONDataTypeFromString(elem);
    }
    else if ([elem JSONDataType] == RIXJSONDataTypeArray) {
        return RIXJSONDataTypeFromStrings(elem);
    }
    else {
        return RIXJSONDataTypeMaskAll;
    }
}

- (void)pushSchema:(NSDictionary *)schema
documentPathComponent:(id)pathComponent
 schemaPathSegment:(NSString *)schemaPathSegment;
{
    if (!_schemaStack) {
        _schemaStack = [[NSMutableArray alloc] init];
    }
    RIXJSONSchemaValidatorSchema *topSchema = [_schemaStack lastObject];
    NSURL *URI = [topSchema.URI URIRelativeToJSONReference:[NSString stringWithFormat:@"#%@", schemaPathSegment]];
    RIXJSONSchemaValidatorSchema *schemaObj = [[RIXJSONSchemaValidatorSchema alloc] initWithSchema:schema URI:URI validator:_validator];
    [_schemaStack addObject:schemaObj];
    [_currentJSONPath addObject:(pathComponent) ? pathComponent : @""];
}

- (void)pop
{
    [_schemaStack removeLastObject];
    [_currentJSONPath removeLastObject];
}

- (void)pushErrors
{
    [_errors addObject:[[NSMutableArray alloc] init]];
}

- (void)popErrors
{
    [_errors removeLastObject];
}

@end

@interface RIXJSONSchemaDefaultFormatValidator : NSObject <RIXJSONSchemaFormatValidator>
@end
@implementation RIXJSONSchemaDefaultFormatValidator

- (BOOL)isValidValue:(id)value forFormatName:(NSString *)formatName
{
    if ([formatName isEqual:@"date-time"]) {
        return [value isKindOfClass:[NSString class]] && [self isValidDateTime:value];
    }
    else if ([formatName isEqual:@"email"]) {
        return [value isKindOfClass:[NSString class]] && [self isValidEmail:value];
    }
    else if ([formatName isEqual:@"hostname"]) {
        return [value isKindOfClass:[NSString class]] && [self isValidHostname:value];
    }
    else if ([formatName isEqual:@"ipv4"]) {
        return [value isKindOfClass:[NSString class]] && [self isValidIPv4:value];
    }
    else if ([formatName isEqual:@"ipv6"]) {
        return [value isKindOfClass:[NSString class]] && [self isValidIPv6:value];
    }
    else if ([formatName isEqual:@"uri"]) {
        return [value isKindOfClass:[NSString class]] && [self isValidURI:value];
    }
    return YES;
}

- (BOOL)isValidDateTime:(NSString *)value
{
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        // http://tools.ietf.org/html/rfc3339#section-5.6
        formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z'ZZZZZ";
        formatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
        formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    });
    // FIXME: Support fractional seconds
    NSDate *date = [formatter dateFromString:value];
    return (date != nil);
}

- (BOOL)isValidEmail:(NSString *)value
{
    static NSRegularExpression *emailRegex;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // A fairly safe regex which doesn't try to get too clever.
        // http://www.regular-expressions.info/email.html
        NSString *pattern = @"^[a-z0-9!#$%&'*+/=?^_`{|}~-]+"
                "(?:\\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*"
                "@"
                "(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\\.)+"
                "[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$";
        emailRegex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:nil];
    });
    NSUInteger matches = [emailRegex numberOfMatchesInString:value options:0 range:NSMakeRange(0, value.length)];
    return (matches > 0);
}

- (BOOL)isValidHostname:(NSString *)value
{
    static NSRegularExpression *hostnameRegex;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // http://stackoverflow.com/questions/1418423/the-hostname-regex
        NSString *pattern = @"^"
                "(?=.{1,255}$)"
                "[0-9A-Za-z]"
                "(?:(?:[0-9A-Za-z]|-){0,61}[0-9A-Za-z])?"
                "(?:\\.[0-9A-Za-z](?:(?:[0-9A-Za-z]|-){0,61}[0-9A-Za-z])?)*"
                "\\.?"
                "$";
        hostnameRegex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:nil];
    });
    NSUInteger matches = [hostnameRegex numberOfMatchesInString:value options:0 range:NSMakeRange(0, value.length)];
    return (matches > 0);
}

- (BOOL)isValidIPv4:(NSString *)value
{
    // http://stackoverflow.com/questions/1679152/how-to-validate-an-ip-address-with-regular-expression-in-objective-c/10971521#10971521
    const char *utf8 = [value UTF8String];
    struct in_addr dst;
    int success = inet_pton(AF_INET, utf8, &dst);
    return (success != 0);
}

- (BOOL)isValidIPv6:(NSString *)value
{
    const char *utf8 = [value UTF8String];
    struct in6_addr dst6;
    int success = inet_pton(AF_INET6, utf8, &dst6);
    return (success != 0);
}

- (BOOL)isValidURI:(NSString *)value
{
    // XXX: NSURL handles many URIs but not all. This is the most convenient test.
    NSURL *URL = [NSURL URLWithString:value];
    return (URL != nil);
}

@end

@implementation RIXJSONSchemaBundleURIResolver

- (instancetype)init
{
    return [super init];
}

- (instancetype)initWithBundle:(NSBundle *)bundle
{
    self = [super init];
    if (self) {
        _bundle = bundle;
    }
    return self;
}

- (NSDictionary *)schemaForURI:(NSURL *)URI
{
    if (![URI.scheme isEqual:@"bundle"]) {
        return nil;
    }
    NSBundle *bundle;
    if (URI.host) {
        bundle = [NSBundle bundleWithIdentifier:URI.host];
    }
    else if (_bundle) {
        bundle = _bundle;
    }
    else {
        bundle = [NSBundle mainBundle];
    }
    if (!bundle) {
        // No bundle
        return nil;
    }
    NSString *path = [bundle pathForResource:URI.path ofType:nil];
    if (!path) {
        // No such file in bundle
        return nil;
    }
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) {
        // Couldn't load file
        return nil;
    }
    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![obj isKindOfClass:[NSDictionary class]]) {
        // Didn't parse or didn't have an object as its root element
        return nil;
    }
    return obj;
}

@end

@implementation RIXJSONSchemaValidator

- (instancetype)init
{
    return nil;
}

// public
- (instancetype)initWithSchema:(NSDictionary *)schema
{
    self = [super init];
    if (self) {
        if (!schema) {
            return nil;
        }
        _formatValidationEnabled = YES;
        RIXJSONSchemaDefaultFormatValidator *validator = [[RIXJSONSchemaDefaultFormatValidator alloc] init];
        _defaultFormatValidators = @{
            @"date-time": validator,
            @"email": validator,
            @"hostname": validator,
            @"ipv4": validator,
            @"ipv6": validator,
            @"uri": validator,
        };
        NSDictionary *schemaDictCopy = [schema copy];
        _URIToSchema = [[NSMutableDictionary alloc] init];
        NSString *ident = schema[keyMainID];
        NSURL *URI = nil;
        if (ident) {
            URI = [[[NSURL alloc] initWithString:ident] normalizedRootJSONSchemaURI];
        }
        if (!URI) {
            URI = [NSURL defaultRootJSONSchemaURI];
        }
        _rootSchema = [[RIXJSONSchemaValidatorSchema alloc] initWithSchema:schemaDictCopy URI:URI validator:self];
        _URIToSchema[URI] = _rootSchema;
        _URIResolvers = [[NSMutableArray alloc] initWithObjects:[[RIXJSONSchemaBundleURIResolver alloc] init], nil];
    }
    return self;
}

// public
- (void)setFormatValidator:(id<RIXJSONSchemaFormatValidator>)formatValidator
             forFormatName:(NSString *)formatName
{
    if (!formatName) {
        return;
    }
    if (!_customFormatValidators) {
        _customFormatValidators = [[NSMutableDictionary alloc] init];
    }
    [_customFormatValidators setValue:formatValidator forKey:formatName];
}

// public
- (void)addURIResolver:(id<RIXJSONSchemaValidatorURIResolver>)URIResolver
{
    if (!URIResolver) {
        return;
    }
    [_URIResolvers addObject:URIResolver];
}

// public
- (NSArray *)validateJSONValue:(id)value
{
    RIXJSONSchemaValidatorContext *context = [[RIXJSONSchemaValidatorContext alloc] initWithInitialSchema:_rootSchema validator:self];
    [self validateJSONValue:value context:context];
    [context pop];
    return [context currentErrors];
}

- (void)validateJSONValue:(id)value
                  context:(RIXJSONSchemaValidatorContext *)context
{
    NSUInteger possibleDataTypes = [value JSONDataType];
    if (possibleDataTypes == RIXJSONDataTypeUnknown) {
        [context addErrorCode:RIXJSONSchemaValidatorErrorJSONIllegalValueType message:@"Value not a legal JSON value class (%@)", [value class]];
        return;
    }
    NSUInteger allowedDataTypes = [context allowedDataTypes];
    NSUInteger commonDataTypes = possibleDataTypes & allowedDataTypes;
    if (commonDataTypes == 0) {
        NSArray *valueTypeStrings = NSStringsFromRIXJSONDataType(possibleDataTypes);
        NSArray *allowedTypeStrings = NSStringsFromRIXJSONDataType(allowedDataTypes);
        [context addErrorCode:RIXJSONSchemaValidatorErrorValueIncorrectType message:@"Value type(s) [ %@ ] do not match schema type(s) [ %@ ]", [valueTypeStrings componentsJoinedByString:@", "], [allowedTypeStrings componentsJoinedByString:@", "]];
    }
    if (commonDataTypes & (RIXJSONDataTypeNull | RIXJSONDataTypeBoolean)) {
        // Type is correct. Nothing more to validate.
    }
    else if (commonDataTypes & RIXJSONDataTypeObject) {
        [self validateJSONObject:value context:context];
    }
    else if (commonDataTypes & RIXJSONDataTypeArray) {
        [self validateJSONArray:value context:context];
    }
    else if (commonDataTypes & RIXJSONDataTypeString) {
        [self validateJSONString:value context:context];
    }
    else if (commonDataTypes & (RIXJSONDataTypeInteger | RIXJSONDataTypeNumber)) {
        [self validateJSONNumber:value context:context];
    }

    id enumv = context[keyAnyEnum];
    if ([enumv JSONDataType] == RIXJSONDataTypeArray) {
        if (![enumv containsObject:value]) {
            [context addErrorCode:RIXJSONSchemaValidatorErrorValueNotInEnum message:@"Value must be one of the values defined by the enum"];
        }
    }

    id allOf = context[keyAnyAllOf];
    if ([allOf JSONDataType] == RIXJSONDataTypeArray) {
        NSArray *suberrors;
        NSUInteger matchCount = [self numberOfValidatingSchemasForValue:value context:context schemas:allOf suberrors:&suberrors];
        if (matchCount != [allOf count]) {
            [context addErrorCode:RIXJSONSchemaValidatorErrorValueFailedAllOf suberrors:suberrors message:@"Value must validate against all schemas in allOf rule"];
        }
    }

    id anyOf = context[keyAnyAnyOf];
    if ([anyOf JSONDataType] == RIXJSONDataTypeArray) {
        NSArray *suberrors;
        NSUInteger matchCount = [self numberOfValidatingSchemasForValue:value context:context schemas:anyOf suberrors:&suberrors];
        if (matchCount == 0) {
            [context addErrorCode:RIXJSONSchemaValidatorErrorValueFailedAnyOf suberrors:suberrors message:@"Value must validate against at least one schema in anyOf rule"];
        }
    }

    id oneOf = context[keyAnyOneOf];
    if ([oneOf JSONDataType] == RIXJSONDataTypeArray) {
        NSArray *suberrors;
        NSUInteger matchCount = [self numberOfValidatingSchemasForValue:value context:context schemas:oneOf suberrors:&suberrors];
        if (matchCount != 1) {
            [context addErrorCode:RIXJSONSchemaValidatorErrorValueFailedOneOf suberrors:suberrors message:@"Value must validate against exactly one schema in oneOf rule"];
        }
    }

    id not = context[keyAnyNot];
    if ([not JSONDataType] == RIXJSONDataTypeObject) {
        NSUInteger matchCount = [self numberOfValidatingSchemasForValue:value context:context schemas:@[ not ] suberrors:nil];
        if (matchCount != 0) {
            [context addErrorCode:RIXJSONSchemaValidatorErrorValueFailedNot message:@"Value must not validate against schema in not rule"];
        }
    }

    NSString *format = context[keyAnyFormat];
    if (format) {
        id<RIXJSONSchemaFormatValidator> formatValidator = _customFormatValidators[format];
        if (!formatValidator) {
            formatValidator = _defaultFormatValidators[format];
        }
        if (formatValidator) {
            if (![formatValidator isValidValue:value forFormatName:format]) {
                [context addErrorCode:RIXJSONSchemaValidatorErrorValueIncorrectFormat message:@"Value must conform to format \"%@\"", format];
            }
        } // unknown formats pass validation
    }
}

- (NSUInteger)numberOfValidatingSchemasForValue:(id)value
                                        context:(RIXJSONSchemaValidatorContext *)context
                                        schemas:(NSArray *)schemas
                                      suberrors:(out NSArray *__autoreleasing *)suberrorsOut
{
    __block NSUInteger count = 0;
    NSMutableArray *allSuberrors = [[NSMutableArray alloc] init];
    [schemas enumerateObjectsUsingBlock:^(id schema, NSUInteger index, BOOL *stop) {
        if ([schema JSONDataType] == RIXJSONDataTypeObject) {
            [context pushErrors];
            [context pushSchema:schema documentPathComponent:nil schemaPathSegment:[NSString stringWithFormat:@"%@/%li", keyAnyAllOf, (long)index]];
            [self validateJSONValue:value context:context];
            NSArray *suberrors = [context currentErrors];
            if (suberrors.count > 0) {
                [allSuberrors addObject:suberrors];
            }
            [context pop];
            [context popErrors];
            if (suberrors.count == 0) {
                count++;
            }
        }
    }];
    if (suberrorsOut) {
        *suberrorsOut = allSuberrors;
    }
    return count;
}


- (void)validateJSONObject:(NSDictionary *)object
                   context:(RIXJSONSchemaValidatorContext *)context
{
    NSNumber *minProperties = context[keyObjectMinProperties];
    if (minProperties) {
        if (object.count < [minProperties integerValue]) {
            [context addErrorCode:RIXJSONSchemaValidatorErrorObjectTooFewProperties message:@"Object must have at least %i properties", [minProperties integerValue]];
        }
    }

    NSNumber *maxProperties = context[keyObjectMaxProperties];
    if (maxProperties) {
        if (object.count > [maxProperties integerValue]) {
            [context addErrorCode:RIXJSONSchemaValidatorErrorObjectTooManyProperties message:@"Object must have no more than %i properties", [maxProperties integerValue]];
        }
    }

    NSArray *required = context[keyObjectRequired];
    if (required) {
        for (NSString *key in required) {
            if (!object[key]) {
                [context addErrorCode:RIXJSONSchemaValidatorErrorObjectMissingRequiredProperty message:@"Object must contain value for property \"%@\"", key];
            }
        }
    }

    NSDictionary *properties = context[keyObjectProperties];
    NSDictionary *patternProperties = context[keyObjectPatternProperties];
    id additionalProperties = context[keyObjectAdditionalProperties];
    [object enumerateKeysAndObjectsUsingBlock:^(NSString *propertyName, id propertyValue, BOOL *stop) {
        __block BOOL schemaFound = NO;
        NSDictionary *propertySchema = properties[propertyName];
        if (propertySchema) {
            [context pushSchema:propertySchema
          documentPathComponent:propertyName
              schemaPathSegment:[NSString stringWithFormat:@"%@/%@", keyObjectProperties, [[propertyName stringByAddingJSONPointerEscapes] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
            [self validateJSONValue:propertyValue context:context];
            [context pop];
            schemaFound = YES;
        }
        else {
            [patternProperties enumerateKeysAndObjectsUsingBlock:^(NSString *pattern, NSDictionary *propertySchema, BOOL *stop) {
                if ([self doesString:propertyName matchPattern:pattern]) {
                    [context pushSchema:propertySchema
                  documentPathComponent:propertyName
                      schemaPathSegment:[NSString stringWithFormat:@"%@/%@", keyObjectPatternProperties, [[pattern stringByAddingJSONPointerEscapes] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
                    [self validateJSONValue:propertyValue context:context];
                    [context pop];
                    schemaFound = YES;
                    // NOTE: Not breaking out of loop. It's possible for
                    // propertyName to match multiple patternProperties. The
                    // draft does not prescribe a proper way of handling this
                    // situation, so I'm choosing to validate against all
                    // matching schemas.
                }
            }];
        }
        if (!schemaFound) {
            if (additionalProperties) {
                if ([additionalProperties JSONDataType] & RIXJSONDataTypeBoolean) {
                    if ([additionalProperties boolValue]) {
                        // Additional properties are allowed but hae no schema
                    }
                    else {
                        // Additional properties are not allowed
                        [context addErrorCode:RIXJSONSchemaValidatorErrorObjectInvalidProperty message:@"Property \"%@\" not allowed", propertyName];
                    }
                }
                else if ([additionalProperties isKindOfClass:[NSDictionary class]]) {
                    NSDictionary *itemSchema = additionalProperties;
                    [context pushSchema:itemSchema documentPathComponent:propertyName schemaPathSegment:keyObjectAdditionalProperties];
                    [self validateJSONValue:propertyValue context:context];
                    [context pop];
                }
            }
        }
    }];

    NSDictionary *dependencies = context[keyObjectDependencies];
    if (dependencies) {
        [dependencies enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
            if (!object[key]) {
                // Key isn't present
                return;
            }
            if ([obj JSONDataType] == RIXJSONDataTypeObject) {
                // Current object must validate against given schema
                [context pushErrors];
                [context pushSchema:obj documentPathComponent:nil schemaPathSegment:[NSString stringWithFormat:@"%@/%@", keyObjectDependencies, [key stringByAddingJSONPointerEscapes]]];
                [self validateJSONObject:object context:context];
                NSArray *errors = [context currentErrors];
                [context pop];
                [context popErrors];
                if (errors.count > 0) {
                    [context addErrorCode:RIXJSONSchemaValidatorErrorObjectFailedDependency message:@"Object must validate against schema in \"dependencies/%@\" when \"%@\" is present in object", key, key];
                }
            }
            else if ([obj JSONDataType] == RIXJSONDataTypeArray) {
                // Current object must also contain values for all the property names in this array
                for (id elem in obj) {
                    if (!object[elem]) {
                        [context addErrorCode:RIXJSONSchemaValidatorErrorObjectFailedDependency message:@"Property \"%@\" must be present when \"%@\" is present", elem, key];
                    }
                }
            }
        }];
    }
}

- (void)validateJSONArray:(NSArray *)array
                  context:(RIXJSONSchemaValidatorContext *)context
{
    NSNumber *minItems = context[keyArrayMinItems];
    if (minItems) {
        if (array.count < [minItems integerValue]) {
            [context addErrorCode:RIXJSONSchemaValidatorErrorArrayTooFewElements message:@"Array must have at least %i elements", [minItems integerValue]];
        }
    }

    NSNumber *maxItems = context[keyArrayMaxItems];
    if (maxItems) {
        if (array.count > [maxItems integerValue]) {
            [context addErrorCode:RIXJSONSchemaValidatorErrorArrayTooManyElements message:@"Array must have no more than %i elements", [maxItems integerValue]];
        }
    }

    BOOL uniqueItems = [context boolForKey:keyArrayUniqueItems orDefault:NO];
    if (uniqueItems) {
        NSMutableSet *set = [[NSMutableSet alloc] initWithArray:array];
        if (set.count != array.count) {
            [context addErrorCode:RIXJSONSchemaValidatorErrorArrayElementsNotUnique message:@"Array elements must be unique"];
        }
    }

    id items = context[keyArrayItems];
    NSDictionary *singleItemSchema = ([items isKindOfClass:[NSDictionary class]]) ? items : nil;
    NSArray *multipleItemSchemas = ([items isKindOfClass:[NSArray class]]) ? items : nil;
    id additionalItems = context[keyArrayAdditionalItems];
    BOOL allowAdditionalItems = (![additionalItems isKindOfClass:[NSNumber class]] || [additionalItems boolValue]);
    NSDictionary *additionalItemSchema = ([additionalItems isKindOfClass:[NSDictionary class]]) ? additionalItems : nil;
    [array enumerateObjectsUsingBlock:^(id element, NSUInteger index, BOOL *stop) {
        if (singleItemSchema) {
            [context pushSchema:singleItemSchema documentPathComponent:@(index) schemaPathSegment:keyArrayItems];
            [self validateJSONValue:element context:context];
            [context pop];
        }
        else if (multipleItemSchemas && index < multipleItemSchemas.count) {
            [context pushSchema:multipleItemSchemas[index] documentPathComponent:@(index) schemaPathSegment:[NSString stringWithFormat:@"%@/%lu", keyArrayItems, index]];
            [self validateJSONValue:element context:context];
            [context pop];
        }
        else if (allowAdditionalItems) {
            if (additionalItemSchema) {
                [context pushSchema:additionalItemSchema documentPathComponent:@(index) schemaPathSegment:keyArrayAdditionalItems];
                [self validateJSONValue:element context:context];
                [context pop];
            }
        }
        else {
            [context addErrorCode:RIXJSONSchemaValidatorErrorArrayAdditionalElementsInvalid message:@"Array must not contain additional elements"];
            *stop = YES;
        }
    }];
}

- (void)validateJSONNumber:(NSNumber *)number
                   context:(RIXJSONSchemaValidatorContext *)context
{
    double val = [number doubleValue];

    NSNumber *multipleOf = context[keyNumberMultipleOf];
    if (multipleOf) {
        if (([number JSONDataType] & RIXJSONDataTypeInteger) && ([multipleOf JSONDataType] & RIXJSONDataTypeInteger)) {
            // Do an integer modulo if possible
            long long val = [number longLongValue];
            long long mult = [multipleOf longLongValue];
            long long mod = val % mult;
            if (mod != 0) {
                [context addErrorCode:RIXJSONSchemaValidatorErrorNumberNotAMultiple message:@"%lli must be a multiple of %lli", val, mult];
            }
        }
        else {
            // Do a floating point modulo
            double mult = [multipleOf doubleValue];
            double mod = fmod(val, mult);
            // XXX: Would like to add some +/- ULP tolerance here but don't know
            // the best way to do so.
            if (mod != 0.0) {
                [context addErrorCode:RIXJSONSchemaValidatorErrorNumberNotAMultiple message:@"%f must be a multiple of %f", val, mult];
            }
        }
    }

    NSNumber *minimum = context[keyNumberMinimum];
    BOOL exclusiveMinimum = [context boolForKey:keyNumberExclusiveMinimum orDefault:NO];
    if (minimum) {
        if (exclusiveMinimum) {
            if ([number compare:minimum] != NSOrderedDescending) {
                [context addErrorCode:RIXJSONSchemaValidatorErrorNumberBelowMinimum message:@"%@ must be greater than %@", number, minimum];
            }
        }
        else {
            if ([number compare:minimum] == NSOrderedAscending) {
                [context addErrorCode:RIXJSONSchemaValidatorErrorNumberBelowMinimum message:@"%@ must be greater than or equal to %@", number, minimum];
            }
        }
    }

    NSNumber *maximum = context[keyNumberMaximum];
    BOOL exclusiveMaximum = [context boolForKey:keyNumberExclusiveMaximum orDefault:NO];
    if (maximum) {
        if (exclusiveMaximum) {
            if ([number compare:maximum] != NSOrderedAscending) {
                [context addErrorCode:RIXJSONSchemaValidatorErrorNumberAboveMaximum message:@"%@ must be less than %@", number, maximum];
            }
        }
        else {
            if ([number compare:maximum] == NSOrderedDescending) {
                [context addErrorCode:RIXJSONSchemaValidatorErrorNumberAboveMaximum message:@"%@ must be less than or equal to %@", number, maximum];
            }
        }
    }
}

- (void)validateJSONString:(NSString *)string
                   context:(RIXJSONSchemaValidatorContext *)context
{
    NSNumber *minLength = context[keyStringMinLength];
    if (minLength) {
        if (string.length < [minLength integerValue]) {
            [context addErrorCode:RIXJSONSchemaValidatorErrorStringShorterThanMinimumLength message:@"String must be at least %i characters", [minLength integerValue]];
        }
    }

    NSNumber *maxLength = context[keyStringMaxLength];
    if (maxLength) {
        if (string.length > [maxLength integerValue]) {
            [context addErrorCode:RIXJSONSchemaValidatorErrorStringLongerThanMaximumLength message:@"String must be no more than %i characters", [maxLength integerValue]];
        }
    }

    NSString *pattern = context[keyStringPattern];
    if (pattern) {
        if (![self doesString:string matchPattern:pattern]) {
            [context addErrorCode:RIXJSONSchemaValidatorErrorStringDoesNotMatchPattern message:@"String must match regular expression /%@/", pattern];
        }
    }
}

- (RIXJSONSchemaValidatorSchema *)schemaForURI:(NSURL *)URI
{
    NSURL *rootURI = [URI normalizedRootJSONSchemaURI];
    RIXJSONSchemaValidatorSchema *schema = _URIToSchema[rootURI];
    if (schema) {
        RIXJSONSchemaValidatorSchema *retVal = [schema schemaAtJSONPointer:[URI JSONPointer]];
        return retVal;
    }
    for (id<RIXJSONSchemaValidatorURIResolver> URIResolver in _URIResolvers) {
        NSDictionary *schemaJSON = [URIResolver schemaForURI:rootURI];
        if (schemaJSON) {
            schema = [[RIXJSONSchemaValidatorSchema alloc] initWithSchema:schemaJSON URI:rootURI validator:self];
            _URIToSchema[rootURI] = schema;
            RIXJSONSchemaValidatorSchema *retVal = [schema schemaAtJSONPointer:[URI JSONPointer]];
            return retVal;
        }
    }
    return nil;
}

/**
 * Tests if string matches the given regex in pattern. Uses cached
 * NSRegularExpression instances.
 */
- (BOOL)doesString:(NSString *)string
      matchPattern:(NSString *)pattern
{
    NSRegularExpression *regex = [self regularExpressionForPattern:pattern];
    NSInteger matchCount = [regex numberOfMatchesInString:string options:0 range:NSMakeRange(0, string.length)];
    return (matchCount > 0);
}

/**
 * Returns an NSRegularExpression for the given pattern, returning cached
 * instances when possible.
 */
- (NSRegularExpression *)regularExpressionForPattern:(NSString *)pattern
{
    NSRegularExpression *regex = self.patternToRegex[pattern];
    if (regex) {
        return regex;
    }
    NSError *error = nil;
    regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionUseUnicodeWordBoundaries error:&error];
    if (!self.patternToRegex) {
        self.patternToRegex = [[NSMutableDictionary alloc] init];
    }
    self.patternToRegex[pattern] = regex;
    return regex;
}

@end
