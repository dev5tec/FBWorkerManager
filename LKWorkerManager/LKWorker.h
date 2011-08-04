//
//  LKWorker.h
//  LKWorkerManager
//
//  Created by Hashiguchi Hiroshi on 11/08/01.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    LKWorkerStateWaiting = 0,
    LKWorkerStateExecuting,
    LKWorkerStateCompleted,
    LKWorkerStateCanceled,
    LKWorkerStateSuspending
} LKWorkerState;


@class LKWorkerManager;
@protocol LKWorker <NSObject>

@property (nonatomic, assign) LKWorkerState workerState;

// return: YES=finished / NO=not finished
- (BOOL)executeWithWorkerManager:(LKWorkerManager*)workerManager;


@optional
- (void)didSuspendWithWorkerManager:(LKWorkerManager*)workerManager;
- (void)didResumeWithWorkerManager:(LKWorkerManager*)workerManager;
- (void)didCancelWithWorkerManager:(LKWorkerManager*)workerManager;

@end