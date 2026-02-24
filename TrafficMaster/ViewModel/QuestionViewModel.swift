//
//  TestViewModel.swift
//  TrafficMaster
//
//  Created by Влад on 20.02.26.
//
import SwiftUI


@Observable
class QuestionViewModel {
    var currentQuestion: Question?
    var userAnswerIndex: Int?
    var isCorrect: Bool?
    var isAnsweredRandomly: Bool = false
    
    func checkAnswer() {
        if userAnswerIndex == currentQuestion?.correctAnswerIndex {
            isCorrect = true
            
        }
        else {
            isCorrect = false
        }
        
        func markAsGuessed() {
                // ???
            }
    }
    
    
    
}
