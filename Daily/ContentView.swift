//
//  ContentView.swift
//  Daily
//
//  Created by Ashwin, Antony on 25/03/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TaskViewModel()
    @State private var newTaskTitle = ""
    @State private var showAddTask = false
    @State private var editingTask: Task? = nil
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with Stats
                VStack(spacing: 16) {
                    HStack(spacing: 20) {
                        // Level
                        VStack(spacing: 4) {
                            Text("Level")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(viewModel.level)")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.blue)
                        }
                        
                        // Streak
                        VStack(spacing: 4) {
                            Text("Streak")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(.orange)
                                Text("\(viewModel.streak)")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        // Daily Points
                        VStack(spacing: 4) {
                            Text("Points")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(viewModel.dailyPoints)")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.yellow)
                        }
                        
                        Spacer()
                        
                        // Add Button
                        Button(action: { showAddTask = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    
                    // Progress Bar
                    VStack(spacing: 8) {
                        HStack {
                            Text("Progress")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(viewModel.getProgressPercentage() * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: 8)
                                    .foregroundColor(Color(UIColor.systemGray6))
                                
                                // Progress
                                RoundedRectangle(cornerRadius: 8)
                                    .foregroundColor(viewModel.getProgressColor())
                                    .frame(width: geometry.size.width * CGFloat(viewModel.getProgressPercentage()))
                                    .animation(.easeInOut(duration: 0.3), value: viewModel.getProgressPercentage())
                            }
                        }
                        .frame(height: 12)
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 12)
                }
                .background(Color(UIColor.secondarySystemBackground))
                
                // Tasks List
                if viewModel.tasks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No tasks yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Tap the + button to add your first task")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    List {
                        ForEach(viewModel.tasks) { task in
                            TaskRow(task: task, onTap: {
                                viewModel.toggleTask(task)
                            }, onEdit: {
                                editingTask = task
                                showAddTask = true
                            }, onDelete: {
                                if let index = viewModel.tasks.firstIndex(where: { $0.id == task.id }) {
                                    viewModel.deleteTask(at: index)
                                }
                            })
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                }
                
                Spacer()
            }
        }
        .sheet(isPresented: $showAddTask, onDismiss: {
            editingTask = nil
        }) {
            AddTaskSheet(isPresented: $showAddTask, editingTask: $editingTask, onAdd: { title, isEveryday, selectedDays in
                viewModel.addTask(title, isEveryday: isEveryday, recurringDays: selectedDays)
            }, onUpdate: { updatedTask in
                viewModel.updateTask(updatedTask)
            })
        }
    }
}

struct TaskRow: View {
    let task: Task
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button(action: onTap) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundColor(task.isCompleted ? Color(red: 0.0, green: 0.816, blue: 0.518) : Color(red: 1.0, green: 0.27, blue: 0.41))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .foregroundColor(.primary)
                        .strikethrough(task.isCompleted, color: .gray)
                    
                    Text(task.recurrenceText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash.fill")
            }
            
            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .tint(.blue)
        }
    }
}

struct AddTaskSheet: View {
    @Binding var isPresented: Bool
    @Binding var editingTask: Task?
    let onAdd: (String, Bool, Set<Int>) -> Void
    let onUpdate: (Task) -> Void
    @State private var title = ""
    @State private var isEveryday = false
    @State private var selectedDays: Set<Int> = []
    
    let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    var isEditing: Bool {
        editingTask != nil
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    Section("Task Title") {
                        TextField("Enter task", text: $title)
                    }
                    
                    Section("Recurrence") {
                        Toggle("Everyday", isOn: Binding(
                            get: { isEveryday },
                            set: { newValue in
                                isEveryday = newValue
                                if newValue {
                                    selectedDays = Set(0...6)
                                }
                            }
                        ))
                    }
                }
                
                if !isEveryday {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Days")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                        
                        HStack(spacing: 8) {
                            ForEach(0..<7, id: \.self) { index in
                                Button(action: {
                                    if selectedDays.contains(index) {
                                        selectedDays.remove(index)
                                    } else {
                                        selectedDays.insert(index)
                                    }
                                }) {
                                    Text(String(days[index].prefix(1)))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 40)
                                        .background(selectedDays.contains(index) ? Color.blue : Color(UIColor.systemGray6))
                                        .foregroundColor(selectedDays.contains(index) ? .white : .primary)
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                    .background(Color(UIColor.systemBackground))
                }
                
                Spacer()
            }
            .navigationTitle(isEditing ? "Edit Task" : "Add New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                        editingTask = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Update" : "Add") {
                        if !title.trimmingCharacters(in: .whitespaces).isEmpty {
                            if isEditing, var updatedTask = editingTask {
                                updatedTask.title = title
                                updatedTask.isEveryday = isEveryday
                                updatedTask.recurringDays = isEveryday ? Array(0...6) : Array(selectedDays)
                                onUpdate(updatedTask)
                                isPresented = false
                                editingTask = nil
                            } else {
                                onAdd(title, isEveryday, isEveryday ? Set(0...6) : selectedDays)
                                title = ""
                                selectedDays = []
                                isEveryday = false
                            }
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let task = editingTask {
                    title = task.title
                    isEveryday = task.isEveryday
                    selectedDays = Set(task.recurringDays)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
