//
//  LKWorkerManager.h
//  LKWorkerManager
//
//  Created by Hashiguchi Hiroshi on 11/08/01.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LKWorkerQueue.h"

// TODO: TIMEOUT?

typedef enum {
    LKWorkerManagerStateStopping = 0,
    LKWorkerManagerStateWaiting,
    LKWorkerManagerStateRunning,
    LKWorkerManagerStatePausing
} LKWorkerManagerState;

//------------------------------------------------------------------------------
@class LKWorker;
@protocol LKWorkerManagerDelegate <NSObject>
@optional
// called in main thread
- (BOOL)canWorkerManagerRun;
- (void)willBeginWorkerManager:(LKWorkerManager*)workerManager worker:(id <LKWorker>)worker;
- (void)didUpdateWorkerManager:(LKWorkerManager*)workerManager worker:(id <LKWorker>)worker;
- (void)didFinishWorkerManager:(LKWorkerManager*)workerManager worker:(id <LKWorker>)worker;
- (void)didCancelWorkerManager:(LKWorkerManager*)workerManager worker:(id <LKWorker>)worker;

@end

//------------------------------------------------------------------------------
@interface LKWorkerManager : NSObject

// API (properties)
@property (nonatomic, assign) NSTimeInterval interval;
@property (nonatomic, assign) id <LKWorkerManagerDelegate> delegate;

// API (properties, readonly)
@property (assign, readonly) LKWorkerManagerState state;
@property (nonatomic, retain, readonly) id <LKWorkerQueue> workerQueue;


// API (general)
+ (LKWorkerManager*)workerManagerWithWorkerQueue:(id <LKWorkerQueue>)workerQueue;
- (void)start;
- (void)pauseAll;
- (void)resumeAll;
- (void)cancelAll;

// API (for worker)
- (void)notifyUpdatedWorker:(id <LKWorker>)worker;

// API (for controller)
- (void)cancelWorker:(id <LKWorker>)worker;
- (void)pauseWorker:(id <LKWorker>)worker;
- (void)resumeWorker:(id <LKWorker>)worker;

@end
