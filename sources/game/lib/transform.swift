struct Transform
{
    private
    var scale:Float,
        rotation:Quaternion,
        translation:Math<Float>.V3

    private(set)
    var model_matrix:[Float],
        model_inverse:[Float],
        rotation_matrix:[Float]

    init(scale:Float = 1,
         rotations:[Quaternion] = [],
         translation:Math<Float>.V3 = (0, 0, 0))
    {
        self.scale = scale
        self.rotation = rotations.reduce(Quaternion(), *)
        self.translation = translation

        self.rotation_matrix = self.rotation.matrix()
        self.model_matrix  = Transform.matrix(scale: scale,
                                              rotation: self.rotation_matrix,
                                              translation: translation)
        self.model_inverse = Transform.inverse_matrix(scale: scale,
                                                      rotation: self.rotation_matrix,
                                                      translation: translation)
    }

    mutating
    func rotate(by rotations:Quaternion...)
    {
        self.rotation = rotations.reduce(self.rotation, *).unit()
    }

    mutating
    func update_matrices()
    {
        self.rotation_matrix = self.rotation.matrix()
        self.model_matrix  = Transform.matrix(scale: self.scale,
                                              rotation: self.rotation_matrix,
                                              translation: self.translation)
        self.model_inverse = Transform.inverse_matrix(scale: self.scale,
                                                      rotation: self.rotation_matrix,
                                                      translation: self.translation)
    }

    private static
    func matrix(scale:Float, rotation:[Float], translation:Math<Float>.V3) -> [Float]
    {
        return [scale*rotation[0]   , scale*rotation[1] , scale*rotation[2] , 0,
                scale*rotation[3]   , scale*rotation[4] , scale*rotation[5] , 0,
                scale*rotation[6]   , scale*rotation[7] , scale*rotation[8] , 0,
                translation.x       , translation.y     , translation.z     , 1]
    }

    private static
    func inverse_matrix(scale:Float, rotation:[Float], translation:Math<Float>.V3) -> [Float]
    {
        let factor:Float = 1/scale
        let A:Float = rotation[0]*factor,
            B:Float = rotation[1]*factor,
            C:Float = rotation[2]*factor,
            D:Float = rotation[3]*factor,
            E:Float = rotation[4]*factor,
            F:Float = rotation[5]*factor,
            G:Float = rotation[6]*factor,
            H:Float = rotation[7]*factor,
            I:Float = rotation[8]*factor
        return [A                                , D                                , G                                , 0,
                B                                , E                                , H                                , 0,
                C                                , F                                , I                                , 0,
                -Math.dot(translation, (A, B, C)), -Math.dot(translation, (D, E, F)), -Math.dot(translation, (G, H, I)), 1]
    }
}
