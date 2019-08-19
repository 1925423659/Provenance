//
//  SteamControllerManager.m
//  SteamController
//
//  Created by Jesús A. Álvarez on 16/12/2018.
//  Copyright © 2018 namedfork. All rights reserved.
//

#import "SteamControllerManager.h"
#import "SteamController.h"

@import CoreBluetooth;
@import ObjectiveC.runtime;

@interface SteamController (Private)
- (void)didConnect;
- (void)didDisconnect;
@end

@interface SteamControllerManager () <CBCentralManagerDelegate, CBPeripheralDelegate>
@end

@implementation SteamControllerManager
{
    CBCentralManager *centralManager;
    CBUUID *controllerServiceUUID;
    NSMutableDictionary<NSUUID*,SteamController*> *controllers;
    NSMutableSet<CBPeripheral*> *connectingPeripherals;
}

+ (instancetype)sharedManager {
    static dispatch_once_t onceToken;
    static SteamControllerManager *sharedManager = nil;
    dispatch_once(&onceToken, ^{
        sharedManager = [SteamControllerManager new];
    });
    return sharedManager;
}

- (instancetype)init {
    if ((self = [super init])) {
        controllerServiceUUID = [CBUUID UUIDWithString:@"100F6C32-1735-4313-B402-38567131E5F3"];
        centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
        controllers = [NSMutableDictionary dictionaryWithCapacity:4];
        connectingPeripherals = [NSMutableSet setWithCapacity:4];
    }
    return self;
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
    [connectingPeripherals addObject:peripheral];
    [central connectPeripheral:peripheral options:nil];
}

- (SteamController*)controllerForPeripheral:(CBPeripheral*)peripheral {
    NSUUID *uuid = peripheral.identifier;
    SteamController *controller = nil;
    @synchronized (controllers) {
        controller = controllers[uuid];
        if (controller == nil) {
            controller = [[SteamController alloc] initWithPeripheral:peripheral];
            controllers[uuid] = controller;
        }
    }
    return controller;
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    SteamController *controller = [self controllerForPeripheral:peripheral];
    [connectingPeripherals removeObject:peripheral];
    [controller didConnect];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    SteamController *controller = nil;
    @synchronized (controllers) {
        controller = controllers[peripheral.identifier];
        [controllers removeObjectForKey:peripheral.identifier];
    }
    [connectingPeripherals removeObject:peripheral];
    [controller didDisconnect];
}

- (void)centralManagerDidUpdateState:(nonnull CBCentralManager *)central {
    if (central.state == CBCentralManagerStatePoweredOn) {
        [self scanForControllers];
    }
}

- (NSArray<SteamController *> *)controllers {
    return controllers.allValues;
}

- (void)scanForControllers:(id)sender {
    [self scanForControllers];
}

- (void)scanForControllers {
    if (centralManager.state == CBCentralManagerStatePoweredOn) {
        [centralManager scanForPeripheralsWithServices:@[controllerServiceUUID] options:nil];
        NSArray *peripherals = [centralManager retrieveConnectedPeripheralsWithServices:@[controllerServiceUUID]];
        for (CBPeripheral *peripheral in peripherals) {
            if (peripheral.state == CBPeripheralStateDisconnected) {
                [connectingPeripherals addObject:peripheral];
                [centralManager connectPeripheral:peripheral options:nil];
            } // TODO: something if it's disconnected?
        }
    }
}

+ (void)load {
    Method m1 = class_getClassMethod([GCController class], @selector(controllers));
    Method m2 = class_getClassMethod([SteamControllerManager class], @selector(controllers));
    Method m3 = class_getClassMethod([SteamControllerManager class], @selector(originalControllers));
    method_exchangeImplementations(m1, m3);
    method_exchangeImplementations(m1, m2);
}

+ (NSArray<GCController*>*)originalControllers {
    return @[];
}

+ (NSArray<GCController*>*)controllers {
    NSArray<GCController*>* originalControllers = [SteamControllerManager originalControllers];
    NSArray<GCController*>* steamControllers = [SteamControllerManager sharedManager].controllers;
    return [originalControllers arrayByAddingObjectsFromArray:steamControllers];
}

@end