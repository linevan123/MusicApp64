import SwiftUI

public struct LibraryView: View {
    @ObservedObject var projectService = ProjectService.shared
    @ObservedObject var authService = AuthService.shared
    
    @State private var showNewProjectAlert: Bool = false
    @State private var newProjectTitle: String = ""
    @State private var searchText: String = ""
    
    public init() {}
    
    private var filteredProjects: [Project] {
        if searchText.isEmpty {
            return projectService.projects
        }
        return projectService.projects.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                BounceTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header info
                        headerSection
                        
                        // Search Field
                        searchBar
                        
                        // Project Cards List
                        if filteredProjects.isEmpty {
                            emptyProjectsView
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredProjects) { project in
                                    NavigationLink {
                                        ProjectDetailView(project: project)
                                    } label: {
                                        projectCard(project)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 120) // space for mini player
                }
                .refreshable {
                    await projectService.fetchProjects()
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showNewProjectAlert = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("NEW")
                        }
                        .font(BounceTheme.mono(11, weight: .bold))
                        .foregroundColor(BounceTheme.accent)
                    }
                }
            }
            .alert("Create New Project", isPresented: $showNewProjectAlert) {
                TextField("e.g. Summer 2026 Beat Pack", text: $newProjectTitle)
                Button("Create") {
                    let title = newProjectTitle
                    newProjectTitle = ""
                    Task {
                        _ = await projectService.createProject(title: title)
                    }
                }
                Button("Cancel", role: .cancel) {
                    newProjectTitle = ""
                }
            } message: {
                Text("Organize your lossless bounces, beat packs, or album stems into a private folder.")
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(authService.currentUser?.username ?? "prodbyevan!")
                    .font(BounceTheme.mono(16, weight: .bold))
                    .foregroundColor(BounceTheme.textPrimary)
                
                Text("\(projectService.projects.count) ACTIVE FOLDERS")
                    .font(BounceTheme.mono(10))
                    .foregroundColor(BounceTheme.textSecondary)
            }
            
            Spacer()
            
            Button {
                showNewProjectAlert = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 13, weight: .bold))
                    Text("NEW PROJECT")
                        .font(BounceTheme.mono(11, weight: .bold))
                }
            }
            .buttonStyle(BrutalistButtonStyle(isPrimary: true))
        }
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(BounceTheme.textMuted)
                .font(.system(size: 13))
            
            TextField("Filter projects, beat packs, stems...", text: $searchText)
                .font(BounceTheme.sans(13))
                .foregroundColor(BounceTheme.textPrimary)
        }
        .padding(12)
        .background(BounceTheme.surface)
        .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
    }
    
    // MARK: - Project Card
    private func projectCard(_ project: Project) -> some View {
        HStack(spacing: 16) {
            // Brutalist Folder Icon Box
            ZStack {
                Rectangle()
                    .fill(BounceTheme.surfaceElevated)
                    .frame(width: 60, height: 60)
                    .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
                
                Image(systemName: "folder.fill")
                    .font(.system(size: 24))
                    .foregroundColor(BounceTheme.accent)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(project.title)
                    .font(BounceTheme.mono(14, weight: .bold))
                    .foregroundColor(BounceTheme.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text("\(project.trackCount) TRACKS")
                        .font(BounceTheme.mono(10, weight: .semibold))
                        .foregroundColor(BounceTheme.accent)
                    
                    Text("·")
                        .foregroundColor(BounceTheme.textMuted)
                    
                    Text(Track.formatSeconds(project.totalDuration))
                        .font(BounceTheme.mono(10))
                        .foregroundColor(BounceTheme.textSecondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(BounceTheme.textMuted)
        }
        .padding(14)
        .background(BounceTheme.surface)
        .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
    }
    
    // MARK: - Empty State
    private var emptyProjectsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 44))
                .foregroundColor(BounceTheme.textMuted)
                .padding(.top, 32)
            
            Text("NO PROJECTS FOUND")
                .font(BounceTheme.mono(13, weight: .bold))
                .foregroundColor(BounceTheme.textSecondary)
            
            Button("CREATE PROJECT") {
                showNewProjectAlert = true
            }
            .buttonStyle(BrutalistButtonStyle(isPrimary: true))
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
