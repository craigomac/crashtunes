//
//  main.swift
//  CrashTunes
//
//  Created by Craig on 10/07/2015.
//  Copyright (c) 2015 Mobiquity. All rights reserved.
//

import Foundation

class FMSynthesizer: AKInstrument{
    
    override init() {
        super.init()
        
        // Note Properties
        var note = FMSynthesizerNote()
        
        let envelope = AKADSREnvelope(
            attackDuration:  0.1.ak,
            decayDuration:   0.1.ak,
            sustainLevel:    0.5.ak,
            releaseDuration: 0.3.ak,
            delay: 0.ak
        )
        
        var oscillator = AKFMOscillator()
        oscillator.baseFrequency        = note.frequency
//        oscillator.carrierMultiplier    = note.color.scaledBy(2.ak)
//        oscillator.modulatingMultiplier = note.color.scaledBy(3.ak)
//        oscillator.modulationIndex      = note.color.scaledBy(10.ak)
//        oscillator.amplitude            = envelope.scaledBy(0.25.ak)
        
        setAudioOutput(oscillator)
        
    }
}



class FMSynthesizerNote: AKNote {
    
    // Note Properties
    var frequency = AKNoteProperty(value: 440, minimum: 100, maximum: 40000)
    var color = AKNoteProperty(value: 0, minimum: 0, maximum: 1)
    
    override init() {
        super.init()
        addProperty(frequency)
        addProperty(color)
        
        // Optionally set a default note duration
        duration.setValue(1.0)
    }
    
    convenience init(frequency:Float, color:Float){
        self.init()
        
        self.frequency.setValue(frequency)
        self.color.setValue(color)
    }
}

struct Thread {
    var name:String
    var addresses:[CUnsignedLongLong]
    var crashed:Bool
}

let threadNameExpression  = NSRegularExpression(pattern: "^Thread [0-9]+.*:\\s+(.*)$", options: nil, error: nil)!
let addressExpression = NSRegularExpression(pattern: "^[0-9]+\\s.*(0x000000[0-9a-f]*)\\s.*\\+.*$", options: nil, error: nil)!

var instrument = Mandolin()
AKOrchestra.addInstrument(instrument)
AKOrchestra.start()

for argument in Process.arguments[1 ..< Process.arguments.count] {
    
    if let report = String(contentsOfFile: argument, encoding: NSUTF8StringEncoding, error: nil) {
        println("CrashTunes: \(argument)")
        
        var lines = report.componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet())

        var threadName:String? = nil
        var addresses:[CUnsignedLongLong] = []
        var threadCrashed = false
        var anyThreadCrashed = false

        var threads:[Thread] = []

        for (index, line) in enumerate(lines) {
            let range = NSMakeRange(0, (line as NSString).length)

            if let threadNameMatch = threadNameExpression.matchesInString(line, options: nil, range: range).first as? NSTextCheckingResult {
                if let lastThreadName = threadName where !addresses.isEmpty {
                    threads.append(Thread(name: lastThreadName, addresses: addresses, crashed: threadCrashed))
                }
                threadName = (line as NSString).substringWithRange(threadNameMatch.rangeAtIndex(1))
                threadCrashed = (lines[index+1] as NSString).containsString("Crashed")
                anyThreadCrashed = anyThreadCrashed || threadCrashed
                addresses = []
            }
            
            if let addressMatch = addressExpression.matchesInString(line, options: nil, range: range).first as? NSTextCheckingResult where threadName != nil {
                var address = (line as NSString).substringWithRange(addressMatch.rangeAtIndex(1))

                let scanner = NSScanner(string: address)
                var hexValue: CUnsignedLongLong = 0
                if scanner.scanHexLongLong(&hexValue) {
                    addresses.append(hexValue)
                }
            }
        }
        
        if let lastThreadName = threadName where !addresses.isEmpty {
            threads.append(Thread(name: lastThreadName, addresses: addresses, crashed: threadCrashed))
        }

        // For now, focus on thread that crashed
        for thread in threads {
//           if thread.crashed || !anyThreadCrashed {
            var minAddress:CUnsignedLongLong = 100000000000
                for address in thread.addresses {
                    if address < minAddress {
                        minAddress = address
                    }
                }
            
                for address in thread.addresses {
                    let addressOffset = address - minAddress
                    let frequency = Float(addressOffset / 100000) // logf( Float(hexValue) ) * 100
                    let color = Float(0.5)
                    
                    if frequency < 5 {
                        continue
                    }

                    
                    println("\(address): = \(frequency)")

//                        let note = FMSynthesizerNote(frequency: frequency, color: color)
//                        fmSynthesizer.playNote(note)

                    let note = MandolinNote()
                    note.frequency.setValue(frequency)

                    instrument.playNote(note)
                    NSThread.sleepForTimeInterval(0.2)
                    instrument.stop()
                    NSThread.sleepForTimeInterval(0.1)
                }
            NSThread.sleepForTimeInterval(0.5)
                
//           }
        }
        
        NSThread.sleepForTimeInterval(1.0)
    } else {
        println("File not found: \(argument)")
    }
    
    instrument.stop()
    AKOrchestra.reset()
}




