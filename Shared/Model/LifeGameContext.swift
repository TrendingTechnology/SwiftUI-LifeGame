//
//  LifeGameContext.swift
//  LifeGameApp
//
//  Created by Yusuke Hosonuma on 2020/07/17.
//

import Combine
import LifeGame
import Foundation

final class LifeGameContext {
    var board: AnyPublisher<LifeGameBoard, Never> { _board.eraseToAnyPublisher() }
    var speed: AnyPublisher<Double, Never> { _speed.eraseToAnyPublisher() }
    let isEnabledPlay: PassthroughSubject<Bool, Never> = .init()
    let isEnabledStop: PassthroughSubject<Bool, Never> = .init()
    let isEnabledNext: PassthroughSubject<Bool, Never> = .init()

    fileprivate let _board: CurrentValueSubject<LifeGameBoard, Never>
    private let _speed: CurrentValueSubject<Double, Never>
    private let _BaseInterval = 0.05
    private var _timerPublisher: Cancellable?
    
    private var _state: LifeGameState = StopState() {
        didSet {
            bind()
        }
    }
    
    init(board: LifeGameBoard, speed: Double) {
        _board = .init(board)
        _speed = .init(speed)
    }

    private func bind() {
        isEnabledPlay.send(_state.play() != nil)
        isEnabledStop.send(_state.stop() != nil)
        isEnabledNext.send(_state.next() != nil)
    }

    func finishConfigure() {
        bind()
    }

    // MARK: - Actions

    func play() {
        guard let execute = _state.play() else { assertionFailure(); return }
        _state = execute(self)
    }
    
    func stop() {
        guard let execute = _state.stop() else { assertionFailure(); return }
        _state = execute(self)
    }
    
    func next() {
        guard let execute = _state.next() else { assertionFailure(); return }
        _state = execute(self)
    }
    
    func pause() {
        guard let execute = _state.pause() else { assertionFailure(); return }
        _state = execute(self)
    }
    
    func resume() {
        guard let execute = _state.resume() else { assertionFailure(); return }
        _state = execute(self)
    }
    
    func setPreset(_ preset: BoardPreset) {
        _board.value = preset.board
    }
    
    func clear() {
        _board.value.clear()
    }
    
    func toggle(x: Int, y: Int) {
        _board.value.toggle(x: x, y: y)
    }
    
    func changeSpeed(_ speed: Double) {
        _speed.value = speed
    }
    
    // MARK: File Private - Allow access from states.
    
    fileprivate func startAnimation() {
        let interval = _BaseInterval + (1.0 - _speed.value) * 0.8
        _timerPublisher = Timer.TimerPublisher(interval: interval, runLoop: .main, mode: .default)
            .autoconnect()
            .sink { _ in
                self._board.value.next()
            }
    }
    
    fileprivate func stopAnimation() {
        _timerPublisher?.cancel()
    }
}

typealias StateExecutor = (LifeGameContext) -> LifeGameState

protocol LifeGameState {
    func play()   -> StateExecutor?
    func stop()   -> StateExecutor?
    func next()   -> StateExecutor?
    func pause()  -> StateExecutor?
    func resume() -> StateExecutor?
}

private class BaseState: LifeGameState {
    func play()   -> StateExecutor? { nil }
    func stop()   -> StateExecutor? { nil }
    func next()   -> StateExecutor? { nil }
    func pause()  -> StateExecutor? { nil }
    func resume() -> StateExecutor? { nil }
}

final private class StopState: BaseState {
    override func play() -> StateExecutor? {
        {
            $0.startAnimation()
            return InProgressState()
        }
    }
    
    override func next() -> StateExecutor? {
        {
            $0._board.value.next()
            return self
        }
    }
    
    override func pause() -> StateExecutor? {
        { _ in self }
    }
    
    override func resume() -> StateExecutor? {
        { _ in self }
    }
}

final private class InProgressState: BaseState {
    override func stop() -> StateExecutor? {
        {
            $0.stopAnimation()
            return StopState()
        }
    }
    
    override func pause() -> StateExecutor? {
        {
            $0.stopAnimation()
            return PauseState()
        }
    }
}

final private class PauseState: BaseState {
    override func resume() -> StateExecutor? {
        {
            $0.startAnimation()
            return InProgressState()
        }
    }
}
