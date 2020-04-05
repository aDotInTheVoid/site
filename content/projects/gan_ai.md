---
title: Gan art
subtitle: GSCE Art final piece
---
```go
type TensorHandle struct {
	c *C.TFE_TensorHandle
}
// NewTensorHandle creates a new tensor handle from a tensor.
func NewTensorHandle(t *Tensor) (*TensorHandle, error) {
	status := newStatus()
	cHandle := C.TFE_NewTensorHandle(t.c, status.c)
	if err := status.Err(); err != nil {
			status := newStatus()
```
