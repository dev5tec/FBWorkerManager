//
//  Sample.m
//  FBWorkerManager
//
//  Created by Hashiguchi Hiroshi on 11/08/03.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import "SampleWorker.h"
#import "FBWorkerManager.h"

@implementation SampleWorker
@synthesize title, time, progress, stopped;
@synthesize workerState, workerElapse;
- (BOOL)executeWithWorkerManager:(FBWorkerManager *)workerManager
{
    float inc = ((rand() % 10) + 1)/ 100.0;
    while (!self.stopped && self.progress < 1.0) {
        [NSThread sleepForTimeInterval:0.2];
        self.progress += inc;
        [workerManager notifyUpdatedWorker:self];
    }
    return !self.stopped;
    
    // memo:
    //  'while (!self.stopped && self.progress < 1.0) {'
    //    can be written as
    //  'while ((self.workerState == FBWorkerStateExecuting) && self.progress < 1.0) {'

}

- (void)suspendWithWorkerManager:(FBWorkerManager*)workerManager
{
    self.stopped = YES;
}

- (void)resumeWithWorkerManager:(FBWorkerManager*)workerManager
{
    self.stopped = NO;
}

- (void)cancelWithWorkerManager:(FBWorkerManager*)workerManager
{
    self.stopped = YES;
}

- (void)timeoutWithWorkerManager:(FBWorkerManager*)workerManager
{
    self.stopped = YES;
}

@end
