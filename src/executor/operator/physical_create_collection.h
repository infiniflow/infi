//
// Created by jinhai on 23-3-16.
//

#pragma once

#include "storage/table_def.h"
#include "executor/physical_operator.h"

#include <memory>

namespace infinity {

class PhysicalCreateCollection final : public PhysicalOperator {
public:
    explicit
    PhysicalCreateCollection(SharedPtr<String> schema_name,
                             SharedPtr<String> collection_name,
                             ConflictType conflict_type,
                             u64 table_index,
                             u64 id);

    ~PhysicalCreateCollection() override = default;

    void
    Init() override;

    void
    Execute(SharedPtr<QueryContext>& query_context) override;

    inline SharedPtr<Vector<String>>
    GetOutputNames() const final {
        return MakeShared<Vector<String>>();
    }

    inline u64
    table_index() const {
        return table_index_;
    }

    inline const SharedPtr<String>&
    schema_name() const {
        return schema_name_;
    }

    inline const SharedPtr<String>&
    collection_name() const {
        return collection_name_;
    }

    inline ConflictType
    conflict_type() const {
        return conflict_type_;
    }

private:
    SharedPtr<String> schema_name_{};
    SharedPtr<String> collection_name_{};
    ConflictType conflict_type_{ConflictType::kInvalid};
    u64 table_index_{};

};

}
