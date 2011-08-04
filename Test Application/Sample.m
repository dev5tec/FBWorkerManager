//
//  Sample.m
//  LKWorkerManager
//
//  Created by Hashiguchi Hiroshi on 11/08/03.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import "Sample.h"
#import "LKWorkerManager.h"

@implementation Sample
@synthesize title, status, time, progress;
- (BOOL)executeOnWorkerManager:(LKWorkerManager *)workerManager
{
    while (self.progress < 1.0) {
        if (![self.status isEqualToString:STATUS_LABEL_WORKING]) {
            return NO;
        }
        [NSThread sleepForTimeInterval:0.2];
        self.progress += 0.05;
        [workerManager notifyUpdatedWorker:self];
    }
    self.status = STATUS_LABEL_FINISHED;
    return YES;
}

- (void)pauseOnWorkerManager:(LKWorkerManager*)workerManager
{
    self.status = STATUS_LABEL_PAUSED;
}

- (void)resumeOnWorkerManager:(LKWorkerManager*)workerManager
{
    self.status = STATUS_LABEL_WAITING;
}

-(void)cancelOnWorkerManager:(LKWorkerManager*)workerManager
{
    self.status = STATUS_LABEL_CANCELED;
}

@end
