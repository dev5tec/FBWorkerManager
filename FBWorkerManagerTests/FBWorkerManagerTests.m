//
//  FBWorkerManagerTests.m
//  FBWorkerManagerTests
//
//  Created by Hashiguchi Hiroshi on 11/08/01.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import "FBWorkerManagerTests.h"
#import "FBWorker.h"

//------------------------------------------------------------------------------
@interface TestWorker : NSObject <FBWorker>
@property (assign) BOOL stopped;
@property (nonatomic, assign) int step;
// step
//  0: wating
//  1: executing
//  2: finished

- (void)clear;

@end

@implementation TestWorker
@synthesize workerState, workerElapse;
@synthesize stopped, step;

- (void)clear
{
    self.step = 0;
}

- (BOOL)executeWithWorkerManager:(FBWorkerManager*)workerManager
{
    // total: 2[sec]
    for (int i=0; i < 10; i++) {
        [NSThread sleepForTimeInterval:0.2];
        [workerManager notifyUpdatedWorker:self];
        if (self.stopped) {
            return NO;
        }
    }
    return YES;
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

//------------------------------------------------------------------------------
@implementation FBWorkerManagerTests
@synthesize workerManager, list, canNotRun, testDelegate;

#define TEST_WORKER_NUM 10

- (void)setUp
{
    [super setUp];
    self.workerManager = [FBWorkerManager workerManager];
    self.workerManager.delegate = self;
    self.workerManager.workerSource = self;
    self.list = [NSMutableArray array];
    self.testDelegate = YES;
}


- (void)tearDown
{
    // Tear-down code here.
    self.workerManager = nil;
    self.list = nil;
    [super tearDown];
}

- (id <FBWorker>)nextWorkerWithWorkerManager:(FBWorkerManager *)workerManager
{
    for (id <FBWorker> worker in self.list) {
        if (worker.workerState == FBWorkerStateWaiting) {
            return worker;
        }
    }
    return nil;
}

- (void)testProperties
{
    self.workerManager.timeout = 9999;
    STAssertEquals(self.workerManager.timeout, (NSUInteger)9999, nil);
    self.workerManager.maxWorkers = 8888;
    STAssertEquals(self.workerManager.maxWorkers, (NSUInteger)8888, nil);
}
- (void)testState
{
    // initial (stopping)
    STAssertEquals(self.workerManager.state, FBWorkerManagerStateStopping, nil);

    // stopping -> x
    STAssertFalse([self.workerManager stop], nil);

    // stopping -> running
    STAssertTrue([self.workerManager start], nil);
    STAssertEquals(self.workerManager.state, FBWorkerManagerStateRunning, nil);

    // running -> stopping
    STAssertTrue([self.workerManager stop], nil);
    STAssertEquals(self.workerManager.state, FBWorkerManagerStateStopping, nil);

}

- (void)testExecution1
{
    for (int i=0; i < TEST_WORKER_NUM; i++) {
        TestWorker* worker = [[[TestWorker alloc] init] autorelease];
        [self.list addObject:worker];
    }
    
    self.workerManager.maxWorkers = TEST_WORKER_NUM;
    [self.workerManager start];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2.5]];

    for (int i=0; i < TEST_WORKER_NUM; i++) {
        TestWorker* worker = [self.list objectAtIndex:i];
        STAssertEquals(worker.workerState, FBWorkerStateCompleted, nil);
    }
}

- (void)testExecution2
{
    for (int i=0; i < TEST_WORKER_NUM; i++) {
        TestWorker* worker = [[[TestWorker alloc] init] autorelease];
        [self.list addObject:worker];
    }
    
    self.workerManager.maxWorkers = TEST_WORKER_NUM;
    [self.workerManager start];

    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    
    TestWorker* worker;
    // result)
    // 0,5 : suspended
    // 1,6 : canceled
    // etc : completed    
    
    worker = [self.list objectAtIndex:0];
    [self.workerManager suspendWorker:worker];

    worker = [self.list objectAtIndex:1];
    [self.workerManager cancelWorker:worker];

    worker = [self.list objectAtIndex:5];
    [self.workerManager suspendWorker:worker];

    worker = [self.list objectAtIndex:6];
    [self.workerManager cancelWorker:worker];
    
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2.0]];
    
    int countOfCompleted = 0;
    int countOfCanceled = 0;
    int countOfSuspending = 0;
    int countOfAnother = 0;

    for (int i=0; i < TEST_WORKER_NUM; i++) {
        TestWorker* worker = [self.list objectAtIndex:i];
        switch (worker.workerState) {
            case FBWorkerStateCompleted:
                countOfCompleted++;
                break;
                
            case FBWorkerStateCanceled:
                countOfCanceled++;
                break;
                
            case FBWorkerStateSuspending:
                countOfSuspending++;
                break;
                
            default:
                countOfAnother++;
                break;
        }
    }
    STAssertEquals(countOfCompleted , 6, nil);
    STAssertEquals(countOfCanceled  , 2, nil);
    STAssertEquals(countOfSuspending, 2, nil);
    STAssertEquals(countOfAnother   , 0, nil);
    
    // result)
    // 0 : suspended --> completed
    // 5 : suspended --> canceled

    worker = [self.list objectAtIndex:0];
    [worker clear];
    [self.workerManager resumeWorker:worker];

    worker = [self.list objectAtIndex:5];
    [self.workerManager cancelWorker:worker];

    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:3.0]];

    countOfCompleted = 0;
    countOfCanceled = 0;
    countOfSuspending = 0;
    countOfAnother = 0;
    for (int i=0; i < TEST_WORKER_NUM; i++) {
        TestWorker* worker = [self.list objectAtIndex:i];
        switch (worker.workerState) {
            case FBWorkerStateCompleted:
                countOfCompleted++;
                break;
                
            case FBWorkerStateCanceled:
                countOfCanceled++;
                break;
                
            case FBWorkerStateSuspending:
                countOfSuspending++;
                break;
                
            default:
                countOfAnother++;
                break;
        }
    }
    STAssertEquals(countOfCompleted , 7, nil);
    STAssertEquals(countOfCanceled  , 3, nil);
    STAssertEquals(countOfSuspending, 0, nil);
    STAssertEquals(countOfAnother   , 0, nil);

}

- (void)testStop
{
    // (1) stop
    for (int i=0; i < TEST_WORKER_NUM; i++) {
        TestWorker* worker = [[[TestWorker alloc] init] autorelease];
        [self.list addObject:worker];
    }
    self.workerManager.maxWorkers = 0;

    [self.workerManager start];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    
    TestWorker* worker;
    // result)
    // 0,5 : suspended
    // 1,6 : canceled
    // etc : completed    
    
    worker = [self.list objectAtIndex:0];
    [self.workerManager suspendWorker:worker];
    
    worker = [self.list objectAtIndex:1];
    [self.workerManager cancelWorker:worker];
    
    worker = [self.list objectAtIndex:5];
    [self.workerManager suspendWorker:worker];
    
    worker = [self.list objectAtIndex:6];
    [self.workerManager cancelWorker:worker];

    [self.workerManager stop];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.5]];
    
    int countOfExecuting = 0;
    int countOfCompleted = 0;
    int countOfCanceled = 0;
    int countOfSuspending = 0;
    int countOfAnother = 0;
    
    for (int i=0; i < TEST_WORKER_NUM; i++) {
        TestWorker* worker = [self.list objectAtIndex:i];
        switch (worker.workerState) {
            case FBWorkerStateExecuting:
                countOfExecuting++;
                break;
                
            case FBWorkerStateCompleted:
                countOfCompleted++;
                break;
                
            case FBWorkerStateCanceled:
                countOfCanceled++;
                break;
                
            case FBWorkerStateSuspending:
                countOfSuspending++;
                break;
                
            default:
                countOfAnother++;
                break;
        }
    }
    STAssertEquals(countOfExecuting , 6, nil);
    STAssertEquals(countOfCompleted , 0, nil);
    STAssertEquals(countOfCanceled  , 2, nil);
    STAssertEquals(countOfSuspending, 2, nil);
    STAssertEquals(countOfAnother   , 0, nil);
    
    [self.workerManager start];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2.0]];

    countOfExecuting = 0;
    countOfCompleted = 0;
    countOfCanceled = 0;
    countOfSuspending = 0;
    countOfAnother = 0;
    
    for (int i=0; i < TEST_WORKER_NUM; i++) {
        TestWorker* worker = [self.list objectAtIndex:i];
        switch (worker.workerState) {
            case FBWorkerStateExecuting:
                countOfExecuting++;
                break;
                
            case FBWorkerStateCompleted:
                countOfCompleted++;
                break;
                
            case FBWorkerStateCanceled:
                countOfCanceled++;
                break;
                
            case FBWorkerStateSuspending:
                countOfSuspending++;
                break;
                
            default:
                countOfAnother++;
                break;
        }
    }
    STAssertEquals(countOfExecuting , 0, nil);
    STAssertEquals(countOfCompleted , 6, nil);
    STAssertEquals(countOfCanceled  , 2, nil);
    STAssertEquals(countOfSuspending, 2, nil);
    STAssertEquals(countOfAnother   , 0, nil);

}

- (void)testCanWorkerManagerRun
{
    self.canNotRun = YES;
    for (int i=0; i < TEST_WORKER_NUM; i++) {
        TestWorker* worker = [[[TestWorker alloc] init] autorelease];
        [self.list addObject:worker];
    }
    self.workerManager.maxWorkers = 0;
    [self.workerManager start];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.5]];
    
    int count;
    count = 0;
    for (int i=0; i < TEST_WORKER_NUM; i++) {
        TestWorker* worker = [self.list objectAtIndex:i];
        if (worker.workerState == FBWorkerStateWaiting) {
            count++;
        }
    }    
    STAssertEquals(count, TEST_WORKER_NUM, nil);

    self.canNotRun = NO;
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:3.0]];

    count = 0;
    for (int i=0; i < TEST_WORKER_NUM; i++) {
        TestWorker* worker = [self.list objectAtIndex:i];
        if (worker.workerState == FBWorkerStateCompleted) {
            count++;
        }
    }    
    STAssertEquals(count, TEST_WORKER_NUM, nil);
}

- (void)testTimeout
{
    // (1) timeout 1[sec] => all timeout
    for (int i=0; i < TEST_WORKER_NUM; i++) {
        TestWorker* worker = [[[TestWorker alloc] init] autorelease];
        [self.list addObject:worker];
    }
    self.workerManager.timeout = 1;
    self.workerManager.maxWorkers = 0;
    [self.workerManager start];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2.5]];
    
    int count = 0;
    for (int i=0; i < TEST_WORKER_NUM; i++) {
        TestWorker* worker = [self.list objectAtIndex:i];
        if (worker.workerState == FBWorkerStateTimeout) {
            count++;
        }
    }    
    STAssertEquals(count, TEST_WORKER_NUM, nil);

    // (2) timeout 3[sec] => all ok
    self.workerManager.timeout = 3;

    self.list = [NSMutableArray array];
    for (int i=0; i < TEST_WORKER_NUM; i++) {
        TestWorker* worker = [[[TestWorker alloc] init] autorelease];
        [self.list addObject:worker];
    }
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:3.0]];
    
    count = 0;
    for (int i=0; i < TEST_WORKER_NUM; i++) {
        TestWorker* worker = [self.list objectAtIndex:i];
        if (worker.workerState == FBWorkerStateCompleted) {
            count++;
        }
    }    
    STAssertEquals(count, TEST_WORKER_NUM, nil);

}


- (void)testManageWorker1
{
    TestWorker* worker;
    self.testDelegate = NO;

    // waiting ---------------
    // [o] waiting -> canceled
    worker = [[[TestWorker alloc] init] autorelease];
    STAssertTrue([self.workerManager cancelWorker:worker], nil);
    STAssertEquals(worker.workerState, FBWorkerStateCanceled, nil);

    // [o] waiting -> suspend
    worker = [[[TestWorker alloc] init] autorelease];
    STAssertTrue([self.workerManager suspendWorker:worker], nil);
    STAssertEquals(worker.workerState, FBWorkerStateSuspending, nil);
    
    // [x] waiting -> resume
    worker = [[[TestWorker alloc] init] autorelease];
    STAssertFalse([self.workerManager resumeWorker:worker], nil);
    STAssertEquals(worker.workerState, FBWorkerStateWaiting, nil);

    // canceled ---------------
    // [x] canceled -> canceled
    worker = [[[TestWorker alloc] init] autorelease];
    [self.workerManager cancelWorker:worker];
    STAssertFalse([self.workerManager cancelWorker:worker], nil);
    STAssertEquals(worker.workerState, FBWorkerStateCanceled, nil);
    
    // [x] canceled -> suspend
    worker = [[[TestWorker alloc] init] autorelease];
    [self.workerManager cancelWorker:worker];
    STAssertFalse([self.workerManager suspendWorker:worker], nil);
    STAssertEquals(worker.workerState, FBWorkerStateCanceled, nil);

    // [x] canceled -> resume
    worker = [[[TestWorker alloc] init] autorelease];
    [self.workerManager cancelWorker:worker];
    STAssertFalse([self.workerManager resumeWorker:worker], nil);
    STAssertEquals(worker.workerState, FBWorkerStateCanceled, nil);

    // suspend ---------------
    // [o] suspend -> canceled
    worker = [[[TestWorker alloc] init] autorelease];
    [self.workerManager suspendWorker:worker];
    STAssertTrue([self.workerManager cancelWorker:worker], nil);
    STAssertEquals(worker.workerState, FBWorkerStateCanceled, nil);
    
    // [x] suspend -> suspend
    worker = [[[TestWorker alloc] init] autorelease];
    [self.workerManager suspendWorker:worker];
    STAssertFalse([self.workerManager suspendWorker:worker], nil);
    STAssertEquals(worker.workerState, FBWorkerStateSuspending, nil);

    // [o] suspend -> resume
    worker = [[[TestWorker alloc] init] autorelease];
    [self.workerManager suspendWorker:worker];
    STAssertTrue([self.workerManager resumeWorker:worker], nil);
    STAssertEquals(worker.workerState, FBWorkerStateWaiting, nil);

}

- (void)testManageWorker2
{
    TestWorker* worker;
    
    for (int i=0; i < TEST_WORKER_NUM; i++) {
        worker = [[[TestWorker alloc] init] autorelease];
        [self.list addObject:worker];
    }

    self.workerManager.maxWorkers = 0;
    [self.workerManager start];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.5]];

    // executing ---------------
    // [o] executing -> canceled
    worker = [self.list objectAtIndex:0];
    STAssertTrue([self.workerManager cancelWorker:worker], nil);
    STAssertEquals(worker.workerState, FBWorkerStateCanceled, nil);
    
    // [o] executing -> suspend
    worker = [self.list objectAtIndex:1];
    STAssertTrue([self.workerManager suspendWorker:worker], nil);
    STAssertEquals(worker.workerState, FBWorkerStateSuspending, nil);
    
    // [x] executing -> resume
    worker = [self.list objectAtIndex:2];
    STAssertFalse([self.workerManager resumeWorker:worker], nil);
    STAssertEquals(worker.workerState, FBWorkerStateExecuting, nil);

}

- (void)testManageAllWorkers
{
    TestWorker* worker;
    
    for (int i=0; i < TEST_WORKER_NUM; i++) {
        worker = [[[TestWorker alloc] init] autorelease];
        [self.list addObject:worker];
    }
    self.workerManager.maxWorkers = 0;
    [self.workerManager start];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.5]];

    [self.workerManager suspendAllWorker];
    for (int i=0; i < TEST_WORKER_NUM; i++) {
        worker = [self.list objectAtIndex:i];
        STAssertEquals(worker.workerState, FBWorkerStateSuspending, nil);
    }

    [self.workerManager resumeAllWorker];
    for (int i=0; i < TEST_WORKER_NUM; i++) {
        worker = [self.list objectAtIndex:i];
        STAssertEquals(worker.workerState, FBWorkerStateWaiting, nil);
    }

    [self.workerManager cancelAllWorker];
    for (int i=0; i < TEST_WORKER_NUM; i++) {
        worker = [self.list objectAtIndex:i];
        STAssertEquals(worker.workerState, FBWorkerStateCanceled, nil);
    }
}

// --- delegate test -----------
- (BOOL)canWorkerManagerRun
{
    return !canNotRun;
}

- (void)willBeginWorkerManager:(FBWorkerManager*)workerManager worker:(id <FBWorker>)worker
{
    if (self.testDelegate) {
        STAssertEquals(worker.workerState, FBWorkerStateExecuting, nil);
        TestWorker* testWorker = (TestWorker*)worker;
        STAssertEquals(testWorker.step, 0, nil);
        testWorker.step++;
    }
}

- (void)didUpdateWorkerManager:(FBWorkerManager*)workerManager worker:(id <FBWorker>)worker
{
    if (self.testDelegate) {
        TestWorker* testWorker = (TestWorker*)worker;
        if (testWorker.step == 1) {
            testWorker.step++;
        }
    }
}

- (void)didFinishWorkerManager:(FBWorkerManager*)workerManager worker:(id <FBWorker>)worker
{
    if (self.testDelegate) {
       TestWorker* testWorker = (TestWorker*)worker;
        if (testWorker.stopped) {
            if (testWorker.workerElapse > self.workerManager.timeout) {
                STAssertEquals(testWorker.workerState, FBWorkerStateTimeout, nil);
            } else {
                STAssertEquals(testWorker.workerState, FBWorkerStateCanceled, nil);
            }
        } else {
            STAssertEquals(testWorker.workerState, FBWorkerStateCompleted, nil);        
        }
        STAssertEquals(testWorker.step, 2, nil);
    }
}


@end
