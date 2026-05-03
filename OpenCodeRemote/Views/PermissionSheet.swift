import SwiftUI

struct PermissionSheet: View {
  let request: PermissionRequest
  let onReply: (PermissionReply) -> Void
  
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          // Risk Badge
          HStack {
            riskIcon
            Text(riskText)
              .font(.caption.bold())
          }
          .padding(.horizontal, 10)
          .padding(.vertical, 4)
          .background(riskColor.opacity(0.15))
          .foregroundColor(riskColor)
          .cornerRadius(8)
          
          Text(request.permission)
            .font(.title2.bold())
          
          if let desc = request.description {
            Text(desc)
              .font(.subheadline)
              .foregroundColor(.secondary)
          }
          
          if let command = request.command {
            VStack(alignment: .leading, spacing: 8) {
              Label("命令", systemImage: "terminal")
                .font(.subheadline.bold())
              Text(command)
                .font(.caption.monospaced())
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
          }
          
          if let filePath = request.filePath {
            VStack(alignment: .leading, spacing: 8) {
              Label("文件路径", systemImage: "doc")
                .font(.subheadline.bold())
              Text(filePath)
                .font(.caption.monospaced())
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
          }
          
          if !request.patterns.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              Label("匹配模式", systemImage: "magnifyingglass")
                .font(.subheadline.bold())
              ForEach(request.patterns, id: \.self) { pattern in
                Text("• \(pattern)")
                  .font(.caption.monospaced())
              }
            }
          }
        }
        .padding()
      }
      .navigationTitle("需要权限")
      .navigationBarTitleDisplayMode(.inline)
      .safeAreaInset(edge: .bottom) {
        VStack(spacing: 12) {
          Button(role: .destructive) {
            onReply(.reject)
          } label: {
            Text("拒绝")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          
          Button {
            onReply(.once)
          } label: {
            Text("仅本次允许")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .tint(.blue)
          
          Button {
            onReply(.always)
          } label: {
            Text("始终允许")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
          .tint(.green)
        }
        .padding()
        .background(.background)
      }
    }
    .presentationDetents([.medium, .large])
  }
  
  private var riskColor: Color {
    switch request.risk {
    case .low: return .green
    case .medium: return .orange
    case .high: return .red
    case .critical: return .purple
    }
  }
  
  private var riskText: String {
    switch request.risk {
    case .low: return "低风险"
    case .medium: return "中风险"
    case .high: return "高风险"
    case .critical: return "严重风险"
    }
  }
  
  private var riskIcon: Image {
    switch request.risk {
    case .low: return Image(systemName: "checkmark.shield.fill")
    case .medium: return Image(systemName: "exclamationmark.triangle.fill")
    case .high: return Image(systemName: "exclamationmark.octagon.fill")
    case .critical: return Image(systemName: "xmark.shield.fill")
    }
  }
}
