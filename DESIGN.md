# Hammer Design
The purpose of this document is to flesh out the general structure of the engine before implementation occurs.

## Table of Contents
- [Introduction](#introduction)
- [Philosophy](#philosophy)
    - [Pillars](#pillars)
        - [Code Pillars](#code-pillars)
        - [Tool Pillars](#tool-pillars)
    - [Foot Guns](#foot-guns)
        - [Globals](#globals)
- [Structure](#structure)
- [Core](#core)

## Content

### Introduction
Hammer is a personal project with no sense of scope or timeline therefore the goals stated in this document are highly ambitious. It is not expected that everything spelled out in this document will be implemented. 

---

### Philosophy 
This section is to discuss general patterns and foot guns to look out for. Nothing discussed in this section is absolute. There are always exceptions.

#### Pillars
Pillars in this context are goals that everything created must meet.

##### Code Pillars
- Readable
- Refactorable
- Simple
- Performance Oriented

##### Tool Pillars
Tools are essential when it comes to game development. The higher quality your tools are the more efficient your development processes can be.

The pillars are as follows:
- Fast Iteration Times
- Easy to implement
- Easy to understand

#### Foot Guns 
A foot gun is something that can make it easy to solve problem but typically causes problems later.

##### Globals
Global variables can reduce verbosity and make using certain functionality more convenient. What they give you is as easy fix to access certain state in deeply nested callstacks at the cost of control and thread safety. 

What do I mean by "at the cost of control and thread safety"? You broaden the scope of what state a given function has access to. This reduces the friction in writing code where its difficult to understand the lifetime and mutation of state. This increases complexity which increases the difficulty of maintanence. 

Globals are typically acceptable in the case of debug api's. Zig provides explicit control over what allocators are used which is typically not the case in class C or C++ projects. 

###### Case Study: OpenGL
OpenGL relies on opaque thread local global state that is initialized through a public API. This global state is bound to the thread its initialized on. This limitation does not exist in Vulkan, Metal, or D3D12 because the user has full control over RHI state. 

---

### Core
Core is the standard library of all engine code. It is expected every library or application will depend on it and it is included by default when all new modules are created.