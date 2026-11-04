// SPDX-FileCopyrightText: Copyright 2024 shadPS4 Emulator Project
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <array>
#include <cstdint>

using s8 = std::int8_t;
using s16 = std::int16_t;
using s32 = std::int32_t;
using s64 = std::int64_t;

using u8 = std::uint8_t;
using u16 = std::uint16_t;
using u32 = std::uint32_t;
using u64 = std::uint64_t;

using f32 = float;
using f64 = double;

using u128 = std::array<std::uint64_t, 2>;
static_assert(sizeof(u128) == 16, "u128 must be 128 bits wide");

using VAddr = uintptr_t;
using PAddr = uintptr_t;

#define PS4_SYSV_ABI __attribute__((sysv_abi))

// UDLs for memory size values. u64, not unsigned long long: on Linux u64 is unsigned long and
// VAddr is uintptr_t, so a literal of the other type breaks std::min/max and lambda return type
// deduction (buffer_cache.cpp). On Windows the two types are the same.
constexpr u64 operator""_KB(unsigned long long x) {
    return static_cast<u64>(x) * 1024;
}
constexpr u64 operator""_MB(unsigned long long x) {
    return 1024_KB * static_cast<u64>(x);
}
constexpr u64 operator""_GB(unsigned long long x) {
    return 1024_MB * static_cast<u64>(x);
}
