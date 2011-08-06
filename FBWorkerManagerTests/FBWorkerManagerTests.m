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
@synthesize workerState;
@synthesize stopped, step;

- (void)clear
{
    self.step = 0;
}

- (BOOL)executeWithWorkerManager:(FBWorkerManager*)workerManager
{
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

@end

//------------------------------------------------------------------------------
@implementation FBWorkerManagerTests
@synthesize workerManager, list, canNotRun;

#define TEST_WORKER_NUM 10

- (void)setUp
{
    [super setUp];
    self.workerManager = [FBWorkerManager workerManager];
    self.workerManager.delegate = self;
    self.workerManager.workerSource = self;
    self.list = [NSMutableArray array];
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
    self.workerManager.interval = 9999;
    STAssertEquals(self.workerManager.interval, (NSTimeInterval)9999, nil);
    self.workerManager.maxWorkers = 8888;
    STAssertEquals(self.workerManager.maxWorkers, (NSUInteger)8888, nil);
}
- (void)testState
{
    // initial (stopping)
    STAssertEquals(self.workerManager.state, FBWorkerManagerStateStopping, nil);

    // stopping -> x
    STAssertFalse([self.workerManager stop], nil);
    STAssertFalse([self.workerManager suspend], nil);
    STAssertFalse([self.workerManager resume], nil);

    // stopping -> running
    STAssertTrue([self.workerManager start], nil);
    STAssertEquals(self.workerManager.state, FBWorkerManagerStateRunning, nil);

    // running -> x
    STAssertFalse([self.workerManager start], nil);
    STAssertFalse([self.workerManager resume], nil);

    // running -> stopping
    STAssertTrue([self.workerManager stop], nil);
    STAssertEquals(self.workerManager.state, FBWorkerManagerStateStopping, nil);

    // running -> suspending
    [self.workerManager start];
    STAssertTrue([self.workerManager suspend], nil); // from running
    STAssertEquals(self.workerManager.state, FBWorkerManagerStateSuspending, nil);

    // suspending -> x
    STAssertFalse([self.workerManager suspend], nil);
    STAssertFalse([self.workerManager start], nil);

    // suspending -> running (resume)
    STAssertTrue([self.workerManager resume], nil); // from suspending
    STAssertEquals(self.workerManager.state, FBWorkerManagerStateRunning, nil);

    // suspending -> stopping
    [self.workerManager suspend];
    STAssertTrue([self.workerManager stop], nil);

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

- (void)testCancelAllWorkers1
{
    // wating -> cancel
    for (int i=0; i < TEST_WORKER_NUM; i++) {
        TestWorker* worker = [[[TestWorker alloc] init] autorelease];
        [self.list addObject:worker];
    }
    
    [self.workerManager cancelAllWorkers];
    
    int count = 0;
    for (int i=0; i < TEST_WORKER_NUM; i++) {
        TestWorker* worker = [self.list objectAtIndex:i];
        if (worker.workerState == FBWorkerStateCanceled) {
            count++;
        }
    }    
    STAssertEquals(count, TEST_WORKER_NUM, nil);
}

- (void)testCancelAllWorkers2
{
    // executing -> cancel
    for (int i=0; i < TEST_WORKER_NUM; i++) {
        TestWorker* worker = [[[TestWorker alloc] init] autorelease];
        [self.list addObject:worker];
    }
    
    self.workerManager.maxWorkers = TEST_WORKER_NUM;
    [self.workerManager start];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    [self.workerManager cancelAllWorkers];

    int count = 0;
    for (int i=0; i < TEST_WORKER_NUM; i++) {
        TestWorker* worker = [self.list objectAtIndex:i];
        if (worker.workerState == FBWorkerStateCanceled) {
            count++;
        }
    }    
    STAssertEquals(count, TEST_WORKER_NUM, nil);
}

- (void)testCancelAllWorkers3
{
    // suspending -> cancel
    for (int i=0; i < TEST_WORKER_NUM; i++) {
        TestWorker* worker = [[[TestWorker alloc] init] autorelease];
        [self.list addObject:worker];
    }
    
    self.workerManager.maxWorkers = TEST_WORKER_NUM;
    [self.workerManager start];
    [self.workerManager suspend];
    [self.workerManager cancelAllWorkers];
    
    int count = 0;
    for (int i=0; i < TEST_WORKER_NUM; i++) {
        TestWorker* worker = [self.list objectAtIndex:i];
        if (worker.workerState == FBWorkerStateCanceled) {
            count++;
        }
    }    
    STAssertEquals(count, TEST_WORKER_NUM, nil);
}

- (void)testSuspendAndResume
{
    for (int i=0; i < TEST_WORKER_NUM; i++) {
        TestWorker* worker = [[[TestWorker alloc] init] autorelease];
        [self.list addObject:worker];
    }
    
    self.workerManager.maxWorkers = TEST_WORKER_NUM;
    [self.workerManager start];
    [self.workerManager suspend];
    
    int count = 0;
    for (int i=0; i < TEST_WORKER_NUM; i++) {
        TestWorker* worker = [self.list objectAtIndex:i];
        if (worker.workerState == FBWorkerStateSuspending) {
            count++;
        }
    }    
    STAssertEquals(count, TEST_WORKER_NUM, nil);    

    for (int i=0; i < TEST_WORKER_NUM; i++) {
        TestWorker* worker = [self.list objectAtIndex:i];
        [worker clear];
    }    

    [self.workerManager resume];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    count = 0;
    for (int i=0; i < TEST_WORKER_NUM; i++) {
        TestWorker* worker = [self.list objectAtIndex:i];
        if (worker.workerState == FBWorkerStateExecuting) {
            count++;
        }
    }    
    STAssertEquals(count, TEST_WORKER_NUM, nil);
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
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    [self.workerManager stop];
    
    int count = 0;
    for (int i=0; i < TEST_WORKER_NUM; i++) {
        TestWorker* worker = [self.list objectAtIndex:i];
        if (worker.workerState == FBWorkerStateCanceled) {
            count++;
        }
    }    
    STAssertEquals(count, TEST_WORKER_NUM, nil);

    // (2) add
    for (int i=0; i < TEST_WORKER_NUM; i++) {
        TestWorker* worker = [[[TestWorker alloc] init] autorelease];
        [self.list addObject:worker];
    }
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2.0]];
    count = 0;
    for (int i=TEST_WORKER_NUM; i < TEST_WORKER_NUM*2; i++) {
        TestWorker* worker = [self.list objectAtIndex:i];
        if (worker.workerState == FBWorkerStateWaiting) {
            count++;
        }
    }    
    STAssertEquals(count, TEST_WORKER_NUM, nil);

    // (3) restart
    [self.workerManager start];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2.5]];
    count = 0;
    for (int i=TEST_WORKER_NUM; i < TEST_WORKER_NUM*2; i++) {
        TestWorker* worker = [self.list objectAtIndex:i];
        if (worker.workerState == FBWorkerStateCompleted) {
            count++;
        }
    }    
    STAssertEquals(count, TEST_WORKER_NUM, nil);
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
        NSLog(@"1:%d", worker.workerState);
    }    
    STAssertEquals(count, TEST_WORKER_NUM, nil);
}

// --- delegate test -----------
- (BOOL)canWorkerManagerRun
{
    return !canNotRun;
}

- (void)willBeginWorkerManager:(FBWorkerManager*)workerManager worker:(id <FBWorker>)worker
{
    STAssertEquals(worker.workerState, FBWorkerStateExecuting, nil);
    TestWorker* testWorker = (TestWorker*)worker;
    STAssertEquals(testWorker.step, 0, nil);
    testWorker.step++;
}

- (void)didUpdateWorkerManager:(FBWorkerManager*)workerManager worker:(id <FBWorker>)worker
{
    TestWorker* testWorker = (TestWorker*)worker;
    if (testWorker.step == 1) {
        testWorker.step++;
    }
}

- (void)didFinishWorkerManager:(FBWorkerManager*)workerManager worker:(id <FBWorker>)worker
{
    TestWorker* testWorker = (TestWorker*)worker;
    if (testWorker.stopped) {
        STAssertEquals(testWorker.workerState, FBWorkerStateCanceled, nil);
    } else {
        STAssertEquals(testWorker.workerState, FBWorkerStateCompleted, nil);        
    }
    STAssertEquals(testWorker.step, 2, nil);
}

@end
