import SwiftUI

struct OpenAIConfigView: View {
    @AppStorage("OpenAIAPIKey") private var apiKey: String = ""
    @State private var tempAPIKey: String = ""
    @State private var showingSuccess: Bool = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("API Configuration")) {
                    SecureField("OpenAI API Key", text: $tempAPIKey)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onAppear {
                            tempAPIKey = apiKey
                        }
                    
                    Button(action: {
                        // Save API key
                        apiKey = tempAPIKey
                        
                        // Show success message
                        withAnimation {
                            showingSuccess = true
                        }
                        
                        // Hide success message after delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showingSuccess = false
                            }
                        }
                    }) {
                        Text("Save API Key")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.vertical)
                    
                    if showingSuccess {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("API Key saved successfully!")
                                .foregroundColor(.green)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                        .transition(.opacity)
                    }
                }
                
                Section(header: Text("Instructions")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("To use the Chat feature, you need to provide your own OpenAI API key.")
                            .font(.body)
                        
                        Text("How to get an API key:")
                            .font(.headline)
                            .padding(.top, 5)
                        
                        Text("1. Visit openai.com and sign up for an account")
                        Text("2. Go to your API settings")
                        Text("3. Create a new API key")
                        Text("4. Copy the key and paste it above")
                        
                        Text("Note: Your API key is stored securely on your device and is never shared with anyone else.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 5)
                    }
                    .padding(.vertical, 5)
                }
            }
            .navigationTitle("OpenAI Configuration")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct OpenAIConfigView_Previews: PreviewProvider {
    static var previews: some View {
        OpenAIConfigView()
    }
}