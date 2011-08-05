//
//  FBWorker.h
//  FBWorkerManager
//
//  Created by Hashiguchi Hiroshi on 11/08/01.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    FBWorkerStateWaiting = 0,
    FBWorkerStateExecuting,
    FBWorkerStateCompleted,
    FBWorkerStateCanceled,
    FBWorkerStateSuspending
} FBWorkerState;


@class FBWorkerManager;
@protocol FBWorker <NSObject>

@property (nonatomic, assign) FBWorkerState workerState;

// return: YES=finished / NO=not finished
- (BOOL)executeWithWorkerManager:(FBWorkerManager*)workerManager;


@optional
- (void)didSuspendWithWorkerManager:(FBWorkerManager*)workerManager;
- (void)didResumeWithWorkerManager:(FBWorkerManager*)workerManager;
- (void)didCancelWithWorkerManager:(FBWorkerManager*)workerManager;

@end