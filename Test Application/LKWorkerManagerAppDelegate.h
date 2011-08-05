//
//  LKWorkerManagerAppDelegate.h
//  LKWorkerManager
//
//  Created by Hashiguchi Hiroshi on 11/08/01.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class LKWorkerManagerViewController;

@interface LKWorkerManagerAppDelegate : NSObject <UIApplicationDelegate>
{
    UIBackgroundTaskIdentifier backgroundTaskIdentifer_;
}
@property (nonatomic, retain) IBOutlet UIWindow *window;

@property (nonatomic, retain) IBOutlet LKWorkerManagerViewController *viewController;

@end
