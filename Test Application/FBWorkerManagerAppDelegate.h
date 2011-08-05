//
//  FBWorkerManagerAppDelegate.h
//  FBWorkerManager
//
//  Created by Hashiguchi Hiroshi on 11/08/01.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class FBWorkerManagerViewController;

@interface FBWorkerManagerAppDelegate : NSObject <UIApplicationDelegate>
{
    UIBackgroundTaskIdentifier backgroundTaskIdentifer_;
}
@property (nonatomic, retain) IBOutlet UIWindow *window;

@property (nonatomic, retain) IBOutlet FBWorkerManagerViewController *viewController;

@end
