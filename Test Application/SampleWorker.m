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
@synthesize title, workerState, time, progress, stopped;
- (BOOL)executeWithWorkerManager:(FBWorkerManager *)workerManager
{
    while (!self.stopped && self.progress < 1.0) {
        [NSThread sleepForTimeInterval:0.2];
        self.progress += 0.05;
        [workerManager notifyUpdatedWorker:self];
    }
    return !self.stopped;
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

@end
