/**
 * @author Federico Busato                                                  <br>
 *         Univerity of Verona, Dept. of Computer Science                   <br>
 *         federico.busato@univr.it
 * @date April, 2017
 * @version v2
 *
 * @copyright Copyright © 2017 cuStinger. All rights reserved.
 *
 * @license{<blockquote>
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * * Redistributions of source code must retain the above copyright notice, this
 *   list of conditions and the following disclaimer.
 * * Redistributions in binary form must reproduce the above copyright notice,
 *   this list of conditions and the following disclaimer in the documentation
 *   and/or other materials provided with the distribution.
 * * Neither the name of the copyright holder nor the names of its
 *   contributors may be used to endorse or promote products derived from
 *   this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 * </blockquote>}
 */
#include "Support/Device/PrintExt.cuh"      //cu::printArray
#include "Support/Device/SafeCudaAPI.cuh"   //cuMemcpyToDeviceAsync

namespace cu_stinger_alg {

template<typename T>
inline void ptr2_t<T>::swap() noexcept {
    std::swap(first, second);
}

template<typename T>
TwoLevelQueue<T>::TwoLevelQueue(size_t max_allocated_items) noexcept :
                                     _max_allocated_items(max_allocated_items) {
    cuMalloc(_d_queue_ptrs.first, max_allocated_items);
    cuMalloc(_d_queue_ptrs.second, max_allocated_items);
    cuMemcpyToSymbol(0, d_queue_counter);
}

template<typename T>
inline TwoLevelQueue<T>::~TwoLevelQueue() noexcept {
    cuFree(_d_queue_ptrs.first, _d_queue_ptrs.second);
    delete[] _host_data;
}

template<typename T>
__host__ void TwoLevelQueue<T>::insert(const T& item) noexcept {
#if defined(__CUDA_ARCH__)
    unsigned       ballot = __ballot(true);
    unsigned elected_lane = xlib::__msb(ballot);
    int warp_offset;
    if (xlib::lane_id() == elected_lane)
        warp_offset = atomicAdd(&d_queue_counter, __popc(ballot));
    int offset = __popc(ballot & xlib::LaneMaskLT()) +
                 __shfl(warp_offset, elected_lane);
    _d_queue_ptrs.second[offset] = item;
#else
    cuMemcpyToDeviceAsync(item, _d_queue_ptrs.first + _size);
    _size++;
#endif
}

template<typename T>
__host__ inline void TwoLevelQueue<T>
::insert(const T* items_array, int num_items) noexcept {
    cuMemcpyToDeviceAsync(items_array, num_items, _d_queue_ptrs.first + _size);
    _size += num_items;
}

template<typename T>
__host__ void TwoLevelQueue<T>::swap() noexcept {
    _d_queue_ptrs.swap();
    auto queue_ptrs = reinterpret_cast<ptr2_t<void>&>(_d_queue_ptrs);
    cuMemcpyToSymbolAsync(0, d_queue_counter);
}

/*
template<typename T>
__host__ void TwoLevelQueue<T>::update_size(int size) noexcept {
    _size = size;
}*/
template<typename T>
__host__ const T* TwoLevelQueue<T>::device_ptr_q1() const noexcept {
    return _d_queue_ptrs.first;
}

template<typename T>
__host__ const T* TwoLevelQueue<T>::device_ptr_q2() const noexcept {
    return _d_queue_ptrs.first;
}

template<typename T>
__host__ const T* TwoLevelQueue<T>::host_data() noexcept {
    if (_host_data == nullptr)
        _host_data = new T[_max_allocated_items];
    cuMemcpyToHost(_d_queue_ptrs.second, _size, _host_data);
    return _host_data;
}

template<typename T>
__host__ int TwoLevelQueue<T>::size() const noexcept {
    return _size;
}

template<typename T>
__host__ void TwoLevelQueue<T>::print() const noexcept {
    cu::printArray(_d_queue_ptrs.first, _size);
}

} // namespace cu_stinger_alg
