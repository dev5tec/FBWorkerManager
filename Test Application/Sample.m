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
@synthesize title, workerState, time, progress;
- (BOOL)executeWithWorkerManager:(LKWorkerManager *)workerManager
{
    while (self.progress < 1.0) {
        if (self.workerState != LKWorkerStateExecuting) {
            return NO;
        }
        [NSThread sleepForTimeInterval:0.2];
        self.progress += 0.05;
        [workerManager notifyUpdatedWorker:self];
    }
    return YES;
}

@end
