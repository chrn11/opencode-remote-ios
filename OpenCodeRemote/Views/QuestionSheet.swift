import SwiftUI

struct QuestionSheet: View {
  let question: InteractQuestion
  let onAnswer: (String) -> Void
  
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          if !question.header.isEmpty {
            Text(question.header)
              .font(.subheadline)
              .foregroundColor(.secondary)
          }
          
          Text(question.question)
            .font(.title2.bold())
          
          VStack(spacing: 12) {
            ForEach(question.options, id: \.label) { option in
              Button {
                onAnswer(option.label)
              } label: {
                HStack(alignment: .top, spacing: 12) {
                  Image(systemName: "circle")
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
                  
                  VStack(alignment: .leading, spacing: 4) {
                    Text(option.label)
                      .font(.headline)
                      .foregroundColor(.primary)
                    
                    if let desc = option.description {
                      Text(desc)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                    }
                  }
                  Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
              }
            }
          }
        }
        .padding()
      }
      .navigationTitle("需要选择")
      .navigationBarTitleDisplayMode(.inline)
    }
    .presentationDetents([.medium, .large])
  }
}
