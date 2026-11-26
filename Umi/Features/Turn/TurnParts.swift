final class TurnParts {
    var hearing: HoldHearing?
    var picture: Task<ScreenPicture, any Error>?
    var answering: Task<Void, Never>?
    var speaking: SpokenAnswer?
    var pointing: Pointing?

    func release(_ hearing: HoldHearing) {
        if self.hearing === hearing {
            self.hearing = nil
        }
    }

    func release(_ picture: Task<ScreenPicture, any Error>) {
        if self.picture == picture {
            self.picture = nil
        }
    }

    func release(_ voice: SpokenAnswer) {
        voice.stop()
        if speaking === voice {
            speaking = nil
        }
    }

    func stop() {
        answering?.cancel()
        answering = nil
        hearing?.cancel()
        hearing = nil
        picture?.cancel()
        picture = nil
        speaking?.stop()
        speaking = nil
        pointing?.stop()
        pointing = nil
    }
}
