//
// Created by JinHai on 2022/7/28.
//

#pragma once

#include "executor/physical_operator.h"

namespace infinity {

class PhysicalAlter final : public PhysicalOperator {
public:
    explicit PhysicalAlter(u64 id) : PhysicalOperator(PhysicalOperatorType::kAlter, nullptr, nullptr, id) {}
    ~PhysicalAlter() override = default;

    void
    Init() override;

    void
    Execute(SharedPtr<QueryContext>& query_context) override;

    inline SharedPtr<Vector<String>>
    GetOutputNames() const final {
        return MakeShared<Vector<String>>();
    }
};

}