function [g,B,mu]=BaylissTapering(sidelobedB,N,xyPoints,a)
%%BAYLISSTAPERING The Bayliss tapering is a set of complex amplitude
%          weights for a continuous circular (narrowband) aperture antenna
%          that will form a difference beam (odd symmetry about an axis)
%          and hold the four closest sidelobes to a desired level. Such a
%          tapering can be discretized and applied to the elements in a
%          circular phased array (An array of antenna elements can be
%          viewed as a discrete approximation to a continuous aperture).
%          This function will provide the tapering values at a set of
%          discrete points given by xyPoints (the origin is taken to be the
%          center of the aperture). The radius of the aperture can either
%          be provided or is taken as value of the farthest point provided.
%          This function also returns coefficients for one to efficiently
%          compute the tapering at points on their own. If xyPoints is
%          empty, only the coefficients are returned. The difference axis
%          generated by this function is the y-axis.
%
%INPUTS: sidelobedB The number of decibels of the ratio of the close-in
%             sidelobe voltages to the main lobe voltage. This must be a
%             negative number. A typical value is -30.
%           N The Bayliss tapering is computed using a certain number of
%             terms. Using too many terms can be undesirable as edge
%             illumination increases, as noted in [1]. If this parameter is
%             omitted or an empty matrix is passed, then the default of 17
%             is used. In [1], it is suggested that N be chosen to be
%             <2*a/lambda, where a is the radius of the aperture and
%             lambda the wavelength.
%    xyPoints A 2XnumPoints set of numPoints points in the aperture plane
%             at which the tapering values should be evaluated. If this
%             parameter is omitted or an empty matrix is passed, then an
%             empty matrix is returned for the output g. The center of the
%             aperture is taken to be the origin. 
%           a The radius of the aperture. Tapering weights for points in
%             xyPoints outside of the aperture are taken to be zero. If
%             this parameter is omitted or an empty matrix is passed, then
%             the radius is taken to be the distance of the farthest point
%             from the origin in xyPoints.
%
%OUTPUTS: g The NX1 set of discretized Bayliss tapering values evaluated at
%           the points given in xyPoints. If xyPoints is omitted, then this
%           is an empty matrix. All Bayliss tapering values are imaginary.
%           The values are not normalized.
%     B, mu These two outputs can be used to evaluate the bayliss tapering
%           values at arbitrary points. B is an NX1 vector and mu is an
%           (N+1)X1 vector. Given a 2X1 point xy and a radius of the
%           aperture, set the normalized radius to p=pi*norm(xy)/a and
%           the Bayliss tapering weight g at the point is
%           g=(xy(1)/norm(xy))*sum(B.*besselj(1,mu(1:N)*p));
%
%This function implements the algorithm of [1] using the polynomial
%interpolation values in the table below Figure 4. This approximation means
%that low sidelobe patterns (-45 dB and below) will not have good fidelity
%sidelobes.
%
%EXAMPLE 1:
%Here, we evaluate the tapering values for 30dB down on a fine grid of
%points to plot what the imaginary part of the tapering weights looks
%like. The real part is all zero.
% numPoints=300;
% points1D=linspace(-1,1,numPoints);
% [X,Y]=meshgrid(points1D,points1D);
% %The Bayliss tapering weights, evaluated across the aperture. Points
% %outside the aperture are assigned a weight of 0. All Bayliss weights are
% %imaginary.
% xyPoints=[X(:)';Y(:)'];
% a=1;%Aperture radius=1.
% gBayliss=BaylissTapering(-30,17,xyPoints,a);
% gBayliss=reshape(gBayliss,numPoints,numPoints);
% 
% figure(1)
% clf
% surface(X,Y,imag(gBayliss),'EdgeColor','None')
% colormap(jet(256))
% colorbar()
% view(45,45)
% light()
% axis square
% h1=xlabel('x');
% h2=ylabel('y');
% title('Bayliss Tapering Weight')
% set(gca,'FontSize',14,'FontWeight','bold','FontName','Times')
% set(h1,'FontSize',14,'FontWeight','bold','FontName','Times')
% set(h2,'FontSize',14,'FontWeight','bold','FontName','Times')
%
%EXAMPLE 2:
%Here, we consider the array response when using tapering values for 30dB
%sidelobes on a circular array with lambda/2 spacing between elements.
%First, we create a circular array. The element locations are given in
%terms of the wavelength lambda, so lambda will not appear in the
%equations for the sum beam.
% %First, we create a circular array. The element locations are given in
% %terms of the wavelength lambda, so lambda will not appear in the
% %equations for the sum beam.
% xyVals=getShaped2DLattice([25;25],'circular');
% %Get the tapering. It is -30dB and  nBar=17;
% N=17;
% sidelobedB=-30;
% g=BaylissTapering(sidelobedB,N,xyVals);
% 
% %The tapering matrix
% T=diag(g);
% 
% %Now, display the response with the tapering. We normalize it with
% %respect to the peak value and plot the result in decibels (power).
% [Rsp,U,V]=standardUVBeamPattern(T,xyVals,'NormPowGain');
% 
% figure(1)
% clf
% surface(U,V,10*log10(Rsp),'EdgeColor','None')
% colormap(jet(256));
% caxis([-40,0])
% colorbar()
% view(45,30)
% light()
% axis square
% h1=xlabel('u');
% h2=ylabel('v');
% h3=zlabel('Response, Decibels');
% title('Bayliss Weighted Array Response')
% set(gca,'FontSize',14,'FontWeight','bold','FontName','Times')
% set(h1,'FontSize',14,'FontWeight','bold','FontName','Times')
% set(h2,'FontSize',14,'FontWeight','bold','FontName','Times')
% set(h3,'FontSize',14,'FontWeight','bold','FontName','Times')
%
%Note that the difference pattern produced has a line of symmetry about
%the y axis. To flip the symmetry axis (e.g. for a vertical difference
%beam), then simply use g=BaylissTapering(sidelobedB,N,flipud(xyVals));
%
%REFERENCES:
%[1] E. T. Bayliss, "Design of monopulse antenna difference patterns with
%    low sidelobes," The Bell System Technical Journal, vol. 47, no. 5, pp.
%    623-650, May-Jun. 1968.
%
%August 2016 David F. Crouse, Naval Research Laboratory, Washington D.C.
%(UNCLASSIFIED) DISTRIBUTION STATEMENT A. Approved for public release.

if(nargin<2||isempty(N))
   N=17; 
end

%The definition og the mu_m terms in Equation 6 in [1]. The first zero is
%the one indexed by 0 in the paper. Thus, this goes from mu_0 to mu_N.
mu=BesselJDerivZeros(1,N+1)/pi;

%This holds the coefficients for the interpolating polynomials given below
%Figure 4 in [1]. The polynomials all take the desired sidelobe level in
%decibels as an input parameter. The first row is for the term A, which
%is a translation of the SNR parameter to a parameter in the paper. The
%next four rows are xi_1 to xi_4, which are the locations of the first four
%zeroes in the modified pattern. The final row is for p_0, which is related
%to the point at which the peak of the asymptotic difference pattern=1.
polyCoeffTable=[0.30387530,-0.05042922,-0.00027989,-0.00000343,-0.00000002;
                0.98583020,-0.03338850, 0.00014064, 0.00000190, 0.00000001;
                2.00337487,-0.01141548, 0.00041590, 0.00000373, 0.00000001;
                3.00636321,-0.00683394, 0.00029281, 0.00000161, 0;
                4.00518423,-0.00501795, 0.00021735, 0.00000088, 0;
                0.47972120,-0.01456692,-0.00018739,-0.00000218,-0.00000001];

A  =polyCoeffTable(1,1)+sidelobedB*(polyCoeffTable(1,2)+sidelobedB*(polyCoeffTable(1,3)+sidelobedB*(polyCoeffTable(1,4)+sidelobedB*polyCoeffTable(1,5))));
xi1=polyCoeffTable(2,1)+sidelobedB*(polyCoeffTable(2,2)+sidelobedB*(polyCoeffTable(2,3)+sidelobedB*(polyCoeffTable(2,4)+sidelobedB*polyCoeffTable(2,5))));
xi2=polyCoeffTable(3,1)+sidelobedB*(polyCoeffTable(3,2)+sidelobedB*(polyCoeffTable(3,3)+sidelobedB*(polyCoeffTable(3,4)+sidelobedB*polyCoeffTable(3,5))));
xi3=polyCoeffTable(4,1)+sidelobedB*(polyCoeffTable(4,2)+sidelobedB*(polyCoeffTable(4,3)+sidelobedB*(polyCoeffTable(4,4)+sidelobedB*polyCoeffTable(4,5))));
xi4=polyCoeffTable(5,1)+sidelobedB*(polyCoeffTable(5,2)+sidelobedB*(polyCoeffTable(5,3)+sidelobedB*(polyCoeffTable(5,4)+sidelobedB*polyCoeffTable(5,5))));
%p0 =polyCoeffTable(6,1)+sidelobedB*(polyCoeffTable(6,2)+sidelobedB*(polyCoeffTable(6,3)+sidelobedB*(polyCoeffTable(6,4)+sidelobedB*polyCoeffTable(6,5))));

Z=zeros(N+1,1);
%Equation 15
Z(1)=0;%The Z(0) term
%Now, the moved zeros
Z(2)=xi1;
Z(3)=xi2;
Z(4)=xi3;
Z(5)=xi4;
for k=5:N
    %The location of the non-moved zeros as given by Equation 13.
    Z(k+1)=sqrt(A^2+k^2);
end
%Equation 16 in [1].
sigma=mu(N+1)/Z(N+1);

%No normalization is performed. We just use C=1.
C=1;

B=zeros(N,1);%The first entry is B_0
%Equation 24
for m=0:(N-1)
    num=prod(1-(mu(m+1)./(sigma*Z(2:N))).^2);
    denom=prod(1-(mu(m+1)./mu([1:m,(m+2):N])).^2);
    
    B(m+1)=-(C*1j*2*mu(m+1)^2/besselj(1,pi*mu(m+1)))*num/denom;
end

%If discretized tapering values are desired.
if(nargin>2&&~isempty(xyPoints))
    numPoints=size(xyPoints,2);
    
    if(nargin<4||isempty(a))
        %The maximum distance from the origin to a point is taken to be the
        %radius of the aperture.
        a2=max(sum(xyPoints.^2,1));
        a=sqrt(a2);
    end
    
    g=zeros(numPoints,1);
    for curPoint=1:numPoints
        rho2=sum(xyPoints(:,curPoint).^2,1);

        if(rho2<=a2)
            rho=sqrt(rho2);
            %The normalized radius at this point.
            p=pi*rho/a;
            
            x=xyPoints(1,curPoint);
            cosVal=x/rho;
            
            %Equation 7 in [1].
            g(curPoint)=cosVal*sum(B.*besselj(1,mu(1:N)*p));
        end
    end
else%If no tapering values are requested, return an empty matrix.
    g=[];
end
end

%LICENSE:
%
%The source code is in the public domain and not licensed or under
%copyright. The information and software may be used freely by the public.
%As required by 17 U.S.C. 403, third parties producing copyrighted works
%consisting predominantly of the material produced by U.S. government
%agencies must provide notice with such work(s) identifying the U.S.
%Government material incorporated and stating that such material is not
%subject to copyright protection.
%
%Derived works shall not identify themselves in a manner that implies an
%endorsement by or an affiliation with the Naval Research Laboratory.
%
%RECIPIENT BEARS ALL RISK RELATING TO QUALITY AND PERFORMANCE OF THE
%SOFTWARE AND ANY RELATED MATERIALS, AND AGREES TO INDEMNIFY THE NAVAL
%RESEARCH LABORATORY FOR ALL THIRD-PARTY CLAIMS RESULTING FROM THE ACTIONS
%OF RECIPIENT IN THE USE OF THE SOFTWARE.