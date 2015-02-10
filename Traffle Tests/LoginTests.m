//
//  LoginTests.m
//  Traffle
//
//  Created by Nikolay Derkach on 10/02/2015.
//  Copyright (c) 2015 Nikolay Derkach. All rights reserved.
//

#import "KIFUITestActor+EXAdditions.h"

@implementation LoginTests

- (void)beforeEach
{
    [tester navigateToLoginPage];
}

- (void)afterEach
{
    [tester returnToLoggedOutHomeScreen];
}

- (void)testSuccessfulLogin
{
    [tester enterText:@"user@example.com" intoViewWithAccessibilityLabel:@"Login User Name"];
    [tester enterText:@"thisismypassword" intoViewWithAccessibilityLabel:@"Login Password"];
    [tester tapViewWithAccessibilityLabel:@"Log In"];
    
    // Verify that the login succeeded
    [tester waitForTappableViewWithAccessibilityLabel:@"Welcome"];
}

@end