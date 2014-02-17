//
//  RIXAppDelegate.m
//  JSONSchema
//
//  Created by Ian Albert on 2014-01-22.
//  Copyright (c) 2014 Ian Albert. All rights reserved.
//

#import "RIXAppDelegate.h"

@implementation RIXAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    return YES;
}

@end
