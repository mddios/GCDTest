//
//  ViewController.m
//  GCDTest
//
//  Created by mdd on 15/8/28.
//  Copyright (c) 2015年 mdd. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self barrierTest];
    [self mainThreadDeadLockTest];
    [self deadLockTest];
    [self creatSerialQ];
    [self groupTest];
    [self dispatchSemaphore];
}

#pragma mark - 死锁测试
/**
 在主线程死锁，这种死锁很常见  原因：主队列，如果主线程正在执行代码，就不调度任务；同步执行：一直执行第一个任务直到结束。两者互相等待造成死锁。
 */
- (void)mainThreadDeadLockTest {
    NSLog(@"begin");
    dispatch_sync(dispatch_get_main_queue(), ^{
        // 发生死锁下面的代码不会执行
        NSLog(@"middle");
    });
    // 发生死锁下面的代码不会执行，当然函数也不会返回，后果也最为严重
    NSLog(@"end");
}

/**
 新建线程死锁测试  原因：serialQueue为串行队列，当代码执行到block1时正常，执行到dispatch_sync时，dispatch_sync等待block2执行完毕才会返回，而serialQueue是串行队列，它正在执行block1，只有等block1执行完毕后才会去执行block2，相互等待造成死锁
 */
- (void)deadLockTest {
    // 其它线程的死锁
    dispatch_queue_t serialQueue = dispatch_queue_create("serial_queue", DISPATCH_QUEUE_SERIAL);
    dispatch_async(serialQueue, ^{
        // 串行队列block1
        NSLog(@"begin");
        dispatch_sync(serialQueue, ^{
            // 串行队列block2 发生死锁，下面的代码不会执行
            NSLog(@"middle");
        });
        // 不会打印
        NSLog(@"end");
    });
    // 函数会返回，不影响主线程
    NSLog(@"return");
}

#pragma mark - 一般串行队列
- (void)creatSerialQ {
    // 参数1 队列名称
    // 参数2 队列类型 DISPATCH_QUEUE_SERIAL/NULL串行队列，DISPATCH_QUEUE_CONCURRENT代表并行队列
    // 下面代码为创建一个串行队列，也是实际开发中用的最多的
    dispatch_queue_t serialQ = dispatch_queue_create("队列名", NULL);
    // 获取主队列
    serialQ = dispatch_get_main_queue();
    /* 取得全局队列
     第一个参数：线程优先级
     第二个参数：标记参数，目前没有用，一般传入0
     */
    serialQ = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

// 同步执行
// 第一个参数：执行任务的队列：串行、并行、全局、主队列
// 第二个参数：block任务
void dispatch_sync(dispatch_queue_t queue, dispatch_block_t block);
// 异步执行
void dispatch_async(dispatch_queue_t queue, dispatch_block_t block);
    
    // 同步执行，会阻塞直到下面block中的代码执行完毕，主线程调用死锁
    dispatch_sync(dispatch_get_main_queue(), ^{
        // 主线程，UI更新
    });
    // 异步执行
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        // 要执行的代码
    });

}

/**
 123并发执行，然后barrier，然后456并发执行。注意：不要使用全局并发队列
 */
- (void)barrierTest {
    // 1 创建并发队列
    dispatch_queue_t BCqueue = dispatch_queue_create("BarrierConcurrent", DISPATCH_QUEUE_CONCURRENT);
    
    // 2.1 添加任务123
    dispatch_async(BCqueue, ^{
        NSLog(@"task1,%@", [NSThread currentThread]);
    });
    dispatch_async(BCqueue, ^{
        sleep(3);
        NSLog(@"task2,%@", [NSThread currentThread]);
    });
    dispatch_async(BCqueue, ^{
        sleep(1);
        NSLog(@"task3,%@", [NSThread currentThread]);
    });
    // 2.2 添加barrier
    dispatch_barrier_async(BCqueue, ^{
        NSLog(@"barrier");
    });
    // 2.3 添加任务456
    dispatch_async(BCqueue, ^{
        sleep(1);
        NSLog(@"task4,%@", [NSThread currentThread]);
    });
    dispatch_async(BCqueue, ^{
        NSLog(@"task5,%@", [NSThread currentThread]);
    });
    dispatch_async(BCqueue, ^{
        NSLog(@"task6,%@", [NSThread currentThread]);
    });
}

#pragma mark - 任务组
- (void)groupTest {
    // 创建一个组
    dispatch_group_t group = dispatch_group_create();
    NSLog(@"开始执行");
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        dispatch_group_async(group, dispatch_get_global_queue(0, 0), ^{
            // 关联任务1
            NSLog(@"task1 running in %@",[NSThread currentThread]);
        });
        dispatch_group_async(group, dispatch_get_global_queue(0, 0), ^{
            // 关联任务2
            NSLog(@"task2 running in %@",[NSThread currentThread]);
        });
        dispatch_group_async(group, dispatch_get_global_queue(0, 0), ^{
            // 关联任务3
            NSLog(@"task3 running in %@",[NSThread currentThread]);
        });
        dispatch_group_async(group, dispatch_get_global_queue(0, 0), ^{
            // 关联任务4
            // 等待1秒
            [NSThread sleepForTimeInterval:1];
            NSLog(@"task4 running in %@",[NSThread currentThread]);
        });
        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            // 回到主线程执行
            NSLog(@"mainTask running in %@",[NSThread currentThread]);
        });
    });
}

#pragma mark - 信号量的使用
/// 用于线程间通讯，下面是等待一个网络完成
- (void)dispatchSemaphore {
    NSString *urlString = [@"https://www.baidu.com" stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    // 设置缓存策略为每次都从网络加载 超时时间30秒
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        // 处理完成之后，发送信号量
        NSLog(@"正在处理...");
        dispatch_semaphore_signal(semaphore);
    }] resume];
    // 等待网络处理完成
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSLog(@"处理完成！");
    
}

@end
