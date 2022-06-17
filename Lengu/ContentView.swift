//
//  ContentView.swift
//  Lengu
//
//  Created by Alvaro Lloret Lopez on 17/4/22.
//

import SwiftUI
import Combine
import AVFoundation
import Speech

final class CameraModel: ObservableObject {
    private let service = CameraService()
    @Published var showAlertError = false
    var alertError: AlertError!
    var session: AVCaptureSession
    private var subscriptions = Set<AnyCancellable>()
    
    init() {
        self.session = service.session
        
        service.$shouldShowAlertView.sink { [weak self] (val) in
            self?.alertError = self?.service.alertError
            self?.showAlertError = val
        }
        .store(in: &self.subscriptions)
        
    }
    
    func configure() {
        service.checkForPermissions()
        service.configure()
    }
    
    func flipCamera() {
        service.changeCamera()
    }
    
    func zoom(with factor: CGFloat) {
        service.set(zoom: factor)
    }
    
}

struct ContentView: View {
    @StateObject var model = CameraModel()
    
    @State var currentZoomFactor: CGFloat = 1.0
    
    //
    @State private var isRecording = false
    @State private var permissionStatus = SFSpeechRecognizerAuthorizationStatus.notDetermined
    @State private var errorMessage = "For this functionality to work, you need to provide permission in your settings"
    @State private var transcription = ""
    @State private var task: SFSpeechRecognitionTask? = SFSpeechRecognitionTask()
    @State private var audioEngine = AVAudioEngine()
    @State private var request = SFSpeechAudioBufferRecognitionRequest()
    //
    
    var languagesLabel: some View {
        Rectangle()
            .foregroundColor(Color.gray.opacity(0.4))
            .frame(width: 120, height: 60, alignment: .center)
            .cornerRadius(5)
            .overlay(
                HStack {
                    Text("Available: \n 🇬🇧 → 🇪🇸")
                        .foregroundColor(.white)
                }
            )
    }
    

    var flipCameraButton: some View {
        Button(action: {
            model.flipCamera()
        }, label: {
            Circle()
                .foregroundColor(Color.blue.opacity(0.7))
                .frame(width: 50, height: 50, alignment: .center)
                .overlay(
                    Image(systemName: "camera.rotate.fill")
                        .foregroundColor(.white))
        })
    }
    
    var body: some View {
        GeometryReader { reader in
            ZStack {
                Color.green.opacity(0.9).edgesIgnoringSafeArea(.all)
                
                VStack {
                    
                    Button(action: {
                        transcription = ""
                    }, label: {
                        Rectangle()
                            .foregroundColor(Color.blue.opacity(0.9))
                            .frame(width: 120, height: 45, alignment: .center)
                            .cornerRadius(5)
                            .overlay(
                                HStack {
                                    Text("Clear text")
                                        .foregroundColor(.white)
                                    Image(systemName: "trash.fill")
                                        .foregroundColor(.white)
                                }
                            )
                    })
                    
                    
                    Button(action: {
                        Task
                        {
                            isRecording.toggle()
                            if isRecording {
                                simpleEndHaptic()
                                startSpeechRecognition()
                                
                            }else{
                                simpleBigHaptic()
                                cancelSpeechRecognition()
                            }
                        }
                    }, label: {
                        Rectangle()
                            .foregroundColor(Color.blue.opacity(0.9))
                            .frame(width: 160, height: 45, alignment: .center)
                            .cornerRadius(5)
                            .overlay(
                                HStack {
                                    
                                    Text(isRecording ? "Press to finish" : "Press to start")
                                        .foregroundColor(.white)
                                    Image(systemName: "person.wave.2.fill")
                                        .foregroundColor(.white)
                                    
                                }
                            )
                    })
                    
                    
                    CameraPreview(session: model.session)
                        .gesture(
                            DragGesture().onChanged({ (val) in
                                //  Only accept vertical drag
                                if abs(val.translation.height) > abs(val.translation.width) {
                                    //  Get the percentage of vertical screen space covered by drag
                                    let percentage: CGFloat = -(val.translation.height / reader.size.height)
                                    //  Calculate new zoom factor
                                    let calc = currentZoomFactor + percentage
                                    //  Limit zoom factor to a maximum of 5x and a minimum of 1x
                                    let zoomFactor: CGFloat = min(max(calc, 1), 5)
                                    //  Store the newly calculated zoom factor
                                    currentZoomFactor = zoomFactor
                                    //  Sets the zoom factor to the capture device session
                                    model.zoom(with: zoomFactor)
                                }
                            })
                        )
                        .onAppear {
                            model.configure()
                        }
                        .alert(isPresented: $model.showAlertError, content: {
                            Alert(title: Text(model.alertError.title), message: Text(model.alertError.message), dismissButton: .default(Text(model.alertError.primaryButtonTitle), action: {
                                model.alertError.primaryAction?()
                            }))
                        })
                        .overlay(
                            //Al poner las transcripciones traducidas en el overlay
                            // se pondrá por encima de la vista de la cámara.
                             Text(transcription)
                                 .padding()
                        )
                        .animation(.easeInOut)
                    
                    
                    HStack {
                        
                        Spacer()
                        
                        languagesLabel
                        
                        Spacer()

                        flipCameraButton
                        
                        Spacer()
                        
                    }
                    .padding(.horizontal, 20)
                }
                
            }.onAppear{requestPermission()}
        }
    }
    
    
    //
    
    func requestPermission()  {
        SFSpeechRecognizer.requestAuthorization { (authState) in
            OperationQueue.main.addOperation {
                if authState == .authorized {
                    permissionStatus = .authorized
                } else if authState == .denied {
                    permissionStatus = .denied
                } else if authState == .notDetermined {
                    permissionStatus = .notDetermined
                } else if authState == .restricted {
                    permissionStatus = .restricted
                }
            }
        }
    }
    

    func startSpeechRecognition(){
        let node = audioEngine.inputNode
        let recordingFormat = node.outputFormat(forBus: 0)
        
        node.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, _) in
            request.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            errorMessage = "Error starting the audio engine."
        }
        
        guard let mySpeechRecognizer = SFSpeechRecognizer() else {
            errorMessage = "Recognition is not allowed on your locale."
            return
        }
        
        if !mySpeechRecognizer.isAvailable {
            errorMessage = "Recognition is not available right now. Please try again after some time."
        }
        
        task = mySpeechRecognizer.recognitionTask(with: request) { (response, error) in
            guard let response = response else {
                if error != nil {
                    errorMessage = "For this functionality to work, you need to provide permission in your settings."
                }else {
                    errorMessage = "Problem in giving the response."
                }
                return
            }
            let message = response.bestTranscription.formattedString
            transcription = makeTranslationRequest(text: message)
        }
    }
    
    func cancelSpeechRecognition() {
        task?.finish()
        task?.cancel()
        task = nil
        
        request.endAudio()
        audioEngine.stop()
        
        if audioEngine.inputNode.numberOfInputs > 0 {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
    }
    //
    
    
}


func simpleSuccessHaptic() {
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(.success)
}

func simpleEndHaptic() {
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(.warning)
}

func simpleBigHaptic() {
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(.error)
}



struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


//

