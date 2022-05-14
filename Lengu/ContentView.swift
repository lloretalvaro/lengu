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
    
    
    
    var captureButton: some View {
        Button(action: {
            
        }, label: {
            Circle()
                .foregroundColor(.white)
                .frame(width: 80, height: 80, alignment: .center)
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.8), lineWidth: 2)
                        .frame(width: 65, height: 65, alignment: .center)
                )
        })
    }
    
    
    
    var flipCameraButton: some View {
        Button(action: {
            model.flipCamera()
        }, label: {
            Circle()
                .foregroundColor(Color.gray.opacity(0.2))
                .frame(width: 45, height: 45, alignment: .center)
                .overlay(
                    Image(systemName: "camera.rotate.fill")
                        .foregroundColor(.white))
        })
    }
    
    var body: some View {
        GeometryReader { reader in
            ZStack {
                Color.yellow.edgesIgnoringSafeArea(.all)
                
                VStack {
                    
                    Button(action: {
                        transcription = ""
                    }, label: {
                        Rectangle()
                            .foregroundColor(Color.gray.opacity(0.2))
                            .frame(width: 120, height: 45, alignment: .center)
                            .cornerRadius(5)
                            .overlay(
                                HStack {
                                    Text("Clear text")
                                    Image(systemName: "trash.fill")
                                        .foregroundColor(.white)
                                }
                            )
                    })
                    
                    
                    Button(action: {
                        Task
                        {
                            isRecording.toggle()
                            if isRecording{
                                print("isRecording is true")
                                simpleEndHaptic()
                        
                                startSpeechRecognization()
                                
                            }else{
                                print("isRecording is false")
                                simpleBigHaptic()
                                
                                cancelSpeechRecognization()
                            }
                        }
                    }, label: {
                        Rectangle()
                            .foregroundColor(Color.gray.opacity(0.2))
                            .frame(width: 160, height: 45, alignment: .center)
                            .cornerRadius(5)
                            .overlay(
                                HStack {
                                    
                                    Text(isRecording ? "Press to finish" : "Press to start")
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
                            //Parece que lo que sea que ponga encima del Overlay
                            //  se pondra por encima de la vista de la camara,
                            //  si pongo el cachito de codigo del speech recognition
                            //  aqui funciona bien
                            /**
                             
                            Old way to do speech recogn
                             
                             Text(speechRecognizer.transcript == "" ? "Say something!" : speechRecognizer.transcript)
                                 .padding()
                                 .onAppear{
                                     speechRecognizer.reset()
                                     speechRecognizer.transcribe()
                                 }
                             */
                           
                
                             Text(transcription)
                                 .padding()
                                 
                             
                        )
                        .animation(.easeInOut)
                    
                    
                    HStack {
                        
                        Spacer()
                        
                        captureButton
                        
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
    //closing bracket for vard body some view
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            print("Available")
        } else {
            print("Available")
        }
    }
    
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
    
    // He creado esta funcion para probar que se ejecutara
    // de forma constante al message pillado por el speech recognition
    // por lo que la funcion que haga la traduccion se puede utilizar de
    // la misma manera en startSpeechRecognization()
    func doSomethingWithText(text: String) -> String {
        var text_output: String = text
        if text.contains("a"){
            text_output = text_output + "ONEPIECE"
        }
        
        if text.contains("u"){
            text_output = text_output + "YEAH"
        }
        
        return text_output
    }
    
    func startSpeechRecognization(){
        let node = audioEngine.inputNode
        let recordingFormat = node.outputFormat(forBus: 0)
        
        node.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, _) in
            request.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch let error {
            errorMessage = "Error comes here for starting the audio listner =\(error.localizedDescription)"
        }
        
        guard let myRecognization = SFSpeechRecognizer() else {
            errorMessage = "Recognization is not allow on your local"
            return
        }
        
        if !myRecognization.isAvailable {
            errorMessage = "Recognization is not free right now, Please try again after some time."
        }
        
        task = myRecognization.recognitionTask(with: request) { (response, error) in
            guard let response = response else {
                if error != nil {
                    errorMessage = error?.localizedDescription ?? "For this functionality to work, you need to provide permission in your settings"
                }else {
                    errorMessage = "Problem in giving the response"
                }
                return
            }
            let message = response.bestTranscription.formattedString
            transcription = doSomethingWithText(text: message)
        }
    }
    
    func cancelSpeechRecognization() {
        print("llego al cancel")
        
        task?.finish()
        task?.cancel()
        task = nil
        
        request.endAudio()
        audioEngine.stop()
        
        //MARK: UPDATED
        if audioEngine.inputNode.numberOfInputs > 0 {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
    }
    //
    
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
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
