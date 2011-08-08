//
// Copyright (c) 2011 Five-technology Co.,Ltd.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import <Foundation/Foundation.h>
#import "FBWorker.h"

// TODO: TIMEOUT?

#pragma mark -
@protocol FBWorkerManagerSource <NSObject>

- (id <FBWorker>)nextWorkerWithWorkerManager:(FBWorkerManager*)workerManager;

@end


#pragma mark -
@protocol FBWorkerManagerDelegate <NSObject>
@optional
// called in main thread
- (BOOL)canWorkerManagerRun;
- (void)willBeginWorkerManager:(FBWorkerManager*)workerManager worker:(id <FBWorker>)worker;
- (void)didUpdateWorkerManager:(FBWorkerManager*)workerManager worker:(id <FBWorker>)worker;
- (void)didFinishWorkerManager:(FBWorkerManager*)workerManager worker:(id <FBWorker>)worker;

@end


#pragma mark -
typedef enum {
    FBWorkerManagerStateStopping = 0,
    FBWorkerManagerStateRunning
} FBWorkerManagerState;


@interface FBWorkerManager : NSObject

// API (properties)
@property (nonatomic, assign) NSUInteger timeout;   // [sec]
@property (nonatomic, assign) NSUInteger maxWorkers;
@property (nonatomic, assign) id <FBWorkerManagerDelegate> delegate;
@property (nonatomic, assign) id <FBWorkerManagerSource> workerSource;


// API (properties, readonly)
@property (assign, readonly) FBWorkerManagerState state;
@property (nonatomic, assign, readonly) BOOL isRunning;


// API (general)
+ (FBWorkerManager*)workerManager;
+ (void)enableBackgroundTask;


// API (control)
- (BOOL)start;
- (BOOL)stop;


// API (called by workers)
- (void)notifyUpdatedWorker:(id <FBWorker>)worker;


// API (manage workers)
- (BOOL)cancelWorker:(id <FBWorker>)worker;
- (BOOL)suspendWorker:(id <FBWorker>)worker;
- (BOOL)resumeWorker:(id <FBWorker>)worker;

@end
