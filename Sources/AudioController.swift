import CoreAudio
import AudioToolbox
import Foundation

/// Controls system output volume, mute, and the default output device
/// using the public CoreAudio APIs.
final class AudioController {
    struct Device: Equatable {
        let id: AudioDeviceID
        let name: String
    }

    private let system = AudioObjectID(kAudioObjectSystemObject)

    // MARK: Default device

    func currentOutputID() -> AudioDeviceID {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var dev = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &dev)
        return dev
    }

    func setDefaultOutput(_ id: AudioDeviceID) {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var dev = id
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectSetPropertyData(system, &addr, 0, nil, size, &dev)
    }

    // MARK: Volume

    func volume() -> Double {
        let dev = currentOutputID()
        var addr = volumeAddress()
        var vol = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioHardwareServiceGetPropertyData(dev, &addr, 0, nil, &size, &vol)
        return status == noErr ? Double(vol) : 0
    }

    func setVolume(_ value: Double) {
        let dev = currentOutputID()
        var addr = volumeAddress()
        var vol = Float32(max(0, min(1, value)))
        let size = UInt32(MemoryLayout<Float32>.size)
        AudioHardwareServiceSetPropertyData(dev, &addr, 0, nil, size, &vol)
    }

    private func volumeAddress() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
    }

    // MARK: Mute

    func isMuted() -> Bool {
        let dev = currentOutputID()
        var addr = muteAddress()
        guard AudioObjectHasProperty(dev, &addr) else { return false }
        var muted = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(dev, &addr, 0, nil, &size, &muted)
        return muted != 0
    }

    func setMuted(_ mute: Bool) {
        let dev = currentOutputID()
        var addr = muteAddress()
        guard AudioObjectHasProperty(dev, &addr) else { return }
        var val = UInt32(mute ? 1 : 0)
        let size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectSetPropertyData(dev, &addr, 0, nil, size, &val)
    }

    private func muteAddress() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
    }

    // MARK: Device list

    func outputDevices() -> [Device] {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(0)
        guard AudioObjectGetPropertyDataSize(system, &addr, 0, nil, &size) == noErr else { return [] }
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap { id in
            hasOutputChannels(id) ? Device(id: id, name: deviceName(id)) : nil
        }
    }

    private func hasOutputChannels(_ id: AudioDeviceID) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(0)
        guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr, size > 0 else { return false }
        let raw = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, raw) == noErr else { return false }
        let list = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
        for buffer in list where buffer.mNumberChannels > 0 { return true }
        return false
    }

    private func deviceName(_ id: AudioDeviceID) -> String {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &name)
        guard status == noErr, let cf = name?.takeRetainedValue() else { return "Unknown" }
        return cf as String
    }
}
