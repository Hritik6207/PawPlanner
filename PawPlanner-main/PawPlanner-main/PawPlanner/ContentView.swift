//
//  ContentView.swift
//  PawPlanner
//
//  Created by Abhishek Jadaun on 06/05/24.
//

import SwiftUI
import CoreML
import Vision

struct ContentView: View {
    @State private var selectedImage: UIImage?
    @State private var detectedObjects: [(String, Float)] = []
    @State private var isImagePickerPresented = false

    var body: some View {
        VStack {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding()
                
                Text("Detected Objects:")
                    .font(.headline)
                    .padding(.top)
                
                List(detectedObjects, id: \.0) { object, confidence in
                    Text("\(object): \(String(format: "%.2f", confidence * 100))%")
                }
            } else {
                Button("Select Photo") {
                    self.isImagePickerPresented.toggle()
                }
            }
        }
        .sheet(isPresented: $isImagePickerPresented) {
            ImagePicker(selectedImage: self.$selectedImage)
        }
        .onChange(of: selectedImage) { _ in
            detectObjectsInImage()
        }
    }
    
    private func detectObjectsInImage() {
        guard let image = selectedImage,
              let ciImage = CIImage(image: image) else {
            print("Unable to create CIImage from UIImage")
            return
        }
        
        do {
            let model = try VNCoreMLModel(for: Pawplanner().model)
            let request = VNCoreMLRequest(model: model) { request, error in
                if let error = error {
                    print("Object detection error:", error)
                    return
                }
                
                guard let results = request.results as? [VNRecognizedObjectObservation] else {
                    print("No results found")
                    return
                }
                
                var uniqueObjects: [String: Float] = [:]
                
                for observation in results {
                    guard let objectLabel = observation.labels.first?.identifier else { continue }
                    let precision = observation.confidence
                    
                    if uniqueObjects[objectLabel] == nil {
                        uniqueObjects[objectLabel] = precision
                    }
                }
                
                let objects = uniqueObjects.sorted(by: { $0.key < $1.key })
                
                DispatchQueue.main.async {
                    self.detectedObjects = objects
                }
            }
            
            let handler = VNImageRequestHandler(ciImage: ciImage)
            try handler.perform([request])
        } catch let error {
            print("Error performing object detection:", error)
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = context.coordinator
        imagePicker.sourceType = .photoLibrary
        return imagePicker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
