import Foundation

public enum CompoundStatCoordinateSync {
    public static func syncIndicesAndValues(
        compound: inout CompoundStatValue,
        designAxisOrder: [AxisDefinition]
    ) {
        var indices: [Int] = []
        var values: [Double] = []
        for (index, axis) in designAxisOrder.enumerated() {
            if let value = compound.coords[axis.tag] {
                indices.append(index)
                values.append(value)
            }
        }
        compound.axisIndices = indices
        compound.axisValues = values
    }
}
